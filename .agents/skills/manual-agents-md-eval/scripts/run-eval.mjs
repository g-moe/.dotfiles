#!/usr/bin/env node

import { spawn } from "node:child_process";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// =============================================================================
// Main flow
// =============================================================================
//
// Keep the whole run easy to follow here. The sections below contain the
// details in the same order they are used: sessions, commands, output parsing,
// infrastructure checks, persistence, and command-line options.

const MAX_RETRIES = 3;
const skillRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

// These values belong to one invocation. Keeping them together avoids passing
// the same run state through every small helper below.
let config;
let repo;
let recordPath;
let reviewPath;
let record;
const activeChildren = new Set();
let saveQueue = Promise.resolve();
let authFailure = null;
let nextJob = 0;

/**
 * Run the configured evaluation from start to scoring handoff.
 * - 1. Load config, create the run directory, and build session jobs.
 * - 2. Run jobs, stop on auth failure, and write output.json plus review.json.
 */
async function main() {
	// 1. Resolve the project and config before creating any output.
	const options = readOptions(process.argv.slice(2));
	const project = path.resolve(options.project ?? process.cwd());
	const configPath = path.resolve(
		options.config ?? path.join(skillRoot, "config.json"),
	);
	config = JSON.parse(await readFile(configPath, "utf8"));
	validateConfig(config);

	// 2. Create one timestamped directory for this run.
	repo = path.resolve(project, config.repo);
	const git = await runCommand("git", ["rev-parse", "HEAD"], 5000);
	const commit = git.stdout.trim();
	if (git.exitCode !== 0 || !/^[0-9a-f]{40,64}$/.test(commit))
		throw new Error("Could not resolve the evaluated repository commit");

	const outputRoot = path.resolve(project, config.outputRoot);
	const timestamp = new Date()
		.toISOString()
		.replaceAll(":", "-")
		.replace(/\.\d{3}Z$/, "Z");
	const runDirectory = path.join(outputRoot, timestamp);
	recordPath = path.join(runDirectory, "output.json");
	reviewPath = path.join(runDirectory, "review.json");
	record = {
		version: 1,
		runtime: new Date().toISOString(),
		commit,
		status: "running",
		project,
		configPath,
		reportPath: null,
		test: config.test,
		summary: null,
		summaryFindings: null,
		results: [],
		failure: null,
	};

	await mkdir(runDirectory, { recursive: true });
	await save();

	// 3. Turn every enabled model/run pair into an independent session job.
	const jobs = config.harnesses.flatMap((harness) =>
		harness.models
			.filter((model) => model.enabled)
			.flatMap((model) =>
				Array.from({ length: config.runs }, (_, index) => ({
					harness,
					model,
					run: index + 1,
				})),
			),
	);

	// 4. Ensure an interrupt also stops every harness process we started.
	process.once("SIGINT", () => {
		stop("SIGTERM");
		process.exit(130);
	});
	process.once("SIGTERM", () => {
		stop("SIGTERM");
		process.exit(143);
	});
	process.once("exit", () => stop("SIGTERM"));

	// 5. Share the job list across a fixed number of workers. Each worker runs
	// one complete multi-turn session at a time so turns stay in one thread.
	await Promise.all(
		Array.from(
			{ length: Math.min(config.concurrency, jobs.length) },
			async () => {
				while (!authFailure) {
					const index = nextJob++;
					if (index >= jobs.length) return;
					await runSession(jobs[index]);
				}
			},
		),
	);

	// 6. Auth failure aborts the entire evaluation. Otherwise, hand the compact
	// review file to the invoking model for scoring.
	if (authFailure) {
		record.status = "aborted";
		record.failure = authFailure;
		await save();
		process.stderr.write(`Authentication failed. Raw record: ${recordPath}\n`);
		process.exitCode = 2;
		return;
	}

	record.status = "ready";
	await save();
	await writeFile(reviewPath, `${JSON.stringify(createReview(), null, 2)}\n`);
	process.stdout.write(`${recordPath}\n`);
}

// =============================================================================
// Run one model session
// =============================================================================

/**
 * Run every configured turn for one model session.
 * - in: One harness, model, and run number from the job list.
 * - out: A completed or infrastructure-failed result appended to output.json.
 */
async function runSession({ harness, model, run }) {
	// Start one raw result before sending its first configured message.
	const result = {
		harnessId: harness.id,
		harnessLabel: harness.label,
		model: model.model,
		modelLabel: model.label,
		effort: model.effort ?? null,
		run,
		sessionId: null,
		turns: [],
	};
	record.results.push(result);

	// Send turns in order. Later turns reuse the session ID returned by turn one.
	for (
		let index = 0;
		index < config.test.turns.length && !authFailure;
		index += 1
	) {
		const turn = config.test.turns[index];
		const turnNumber = index + 1;

		// Create the turn record before invoking the harness so interrupted runs
		// still show exactly what had started.
		const captured = {
			turn: turnNumber,
			prompt: turn.prompt,
			status: "running",
			reply: null,
			replyTimeMs: 0,
			replyChars: 0,
			toolCalls: [],
			attempts: 0,
			infrastructureEvents: [],
			stdout: "",
			stderr: "",
			score: null,
		};
		result.turns.push(captured);

		// Select start/resume arguments and replace placeholders without touching
		// the configured prompt itself.
		const template =
			turnNumber === 1 ? harness.startArgs : harness.continueArgs;
		const values = {
			repo,
			model: model.model,
			effort: model.effort ?? "",
			sessionId: result.sessionId ?? "",
			prompt: turn.prompt,
		};
		const args = template.map((argument) => substitute(argument, values));

		// Retry only infrastructure failures. MAX_RETRIES means three retries
		// after the first attempt, for four total attempts.
		let completed;
		let lastProblem;
		for (let attempt = 1; attempt <= MAX_RETRIES + 1; attempt += 1) {
			captured.attempts = attempt;
			const call = await runCommand(
				harness.command,
				args,
				config.timeoutSeconds * 1000,
			);
			const parsed = parseOutput(call.stdout);
			const combined = `${call.stdout}\n${call.stderr}`;

			captured.replyTimeMs += call.elapsedMs;
			captured.stdout += call.stdout;
			captured.stderr += call.stderr;
			captured.reply = parsed.reply || null;
			captured.replyChars = parsed.reply.length;
			captured.toolCalls = parsed.toolCalls;

			const capacityFailure = isCapacityFailure(combined);

			// Authentication is global: stop every active job immediately.
			if (
				call.exitCode !== 0 &&
				!capacityFailure &&
				isAuthenticationFailure(combined)
			) {
				authFailure = {
					kind: "authentication",
					message: combined.trim().slice(0, 2000) || "Authentication failed.",
					harnessId: harness.id,
					model: model.model,
					run,
					turn: turnNumber,
				};
				stop("SIGTERM");
				await save();
				return;
			}

			const problem = infrastructureProblem(call, parsed, turnNumber === 1);
			if (!problem) {
				completed = parsed;
				break;
			}
			lastProblem = problem;

			captured.infrastructureEvents.push(
				`Attempt ${attempt}: ${problem.message}`,
			);
			if (!problem.retry) break;
		}

		// Exhausting the retry budget ends this session and marks later turns as
		// skipped; it does not stop unrelated model sessions.
		if (!completed) {
			captured.status = lastProblem.capacity
				? "at-capacity"
				: "infrastructure-failure";
			await addSkippedTurns(result, turnNumber);
			await save();
			return;
		}

		// Only turn one establishes the thread. Save after each completed turn so
		// a killed evaluation keeps all completed work.
		if (turnNumber === 1) result.sessionId = completed.sessionId;
		captured.status = "completed";
		await save();
		process.stderr.write(
			`${harness.id} | ${model.label} | run ${run} | turn ${turnNumber} complete\n`,
		);
	}
}

/**
 * Build the compact scoring handoff without duplicating raw harness output.
 * - in: The current in-memory evaluation record.
 * - out: A review object containing replies, tool calls, and empty scores.
 */
function createReview() {
	return {
		version: 1,
		outputPath: recordPath,
		test: record.test,
		summaryFindings: [],
		results: record.results.map((result, resultIndex) => ({
			resultIndex,
			harnessLabel: result.harnessLabel,
			modelLabel: result.modelLabel,
			run: result.run,
			turns: result.turns.map((turn, turnIndex) => ({
				turnIndex,
				turn: turn.turn,
				status: turn.status,
				reply: turn.reply,
				toolCalls: turn.toolCalls,
				score: null,
			})),
		})),
	};
}

/**
 * Add placeholders after a turn ends its session.
 * - in: The failed result and the one-based number of its failed turn.
 * - out: The result with every remaining configured turn marked skipped.
 */
async function addSkippedTurns(result, failedTurn) {
	for (let index = failedTurn; index < config.test.turns.length; index += 1) {
		result.turns.push({
			turn: index + 1,
			prompt: config.test.turns[index].prompt,
			status: "skipped",
			reply: null,
			replyTimeMs: 0,
			replyChars: 0,
			toolCalls: [],
			attempts: 0,
			infrastructureEvents: [
				"Skipped because an earlier turn exhausted its retries.",
			],
			stdout: "",
			stderr: "",
			score: null,
		});
	}
}

// =============================================================================
// Run and stop harness commands
// =============================================================================

/**
 * Run one harness command and capture its complete process result.
 * - in: Command, argument list, and timeout in milliseconds.
 * - out: Exit code, stdout, stderr, elapsed time, and timeout state.
 */
function runCommand(command, args, timeoutMs) {
	return new Promise((resolve) => {
		const started = Date.now();
		const child = spawn(command, args, {
			cwd: repo,
			env: process.env,
			detached: process.platform !== "win32",
			stdio: ["ignore", "pipe", "pipe"],
		});
		activeChildren.add(child);

		let stdout = "";
		let stderr = "";
		let timedOut = false;
		let settled = false;

		/**
		 * Resolve the command once and remove it from active process tracking.
		 * - in: Process exit code and an optional spawn error.
		 * - out: The settled runCommand promise.
		 */
		const finish = (exitCode, error = null) => {
			if (settled) return;
			settled = true;
			clearTimeout(timer);
			activeChildren.delete(child);
			if (error) stderr += `${stderr ? "\n" : ""}${error.message}`;
			resolve({
				exitCode: exitCode ?? -1,
				stdout,
				stderr,
				timedOut,
				elapsedMs: Date.now() - started,
			});
		};

		const timer = setTimeout(() => {
			timedOut = true;
			terminate(child, "SIGTERM");
			setTimeout(() => terminate(child, "SIGKILL"), 2000).unref();
		}, timeoutMs);

		child.stdout.on("data", (chunk) => {
			stdout += chunk;
		});
		child.stderr.on("data", (chunk) => {
			stderr += chunk;
		});
		child.once("error", (error) => finish(-1, error));
		child.once("close", (exitCode) => finish(exitCode));
	});
}

/**
 * Stop every harness process still owned by this evaluation.
 * - in: The signal to send to each active process.
 * - out: No return value; active processes receive the signal.
 */
function stop(signal) {
	for (const child of activeChildren) terminate(child, signal);
}

/**
 * Stop one harness process and its Unix process group when available.
 * - in: A child process and the signal to send.
 * - out: No return value; already-finished processes are ignored.
 */
function terminate(child, signal) {
	if (child.exitCode !== null) return;
	try {
		if (process.platform !== "win32" && child.pid)
			process.kill(-child.pid, signal);
		else child.kill(signal);
	} catch {}
}

// =============================================================================
// Normalize harness output
// =============================================================================

/**
 * Normalize newline-delimited Codex or Cursor events.
 * - in: Raw stdout from one harness command.
 * - out: Session ID, final reply text, and normalized completed tool calls.
 */
function parseOutput(stdout) {
	const events = stdout
		.split(/\r?\n/)
		.filter(Boolean)
		.flatMap((line) => {
			try {
				return [JSON.parse(line)];
			} catch {
				return [];
			}
		});
	const objects = events.flatMap(flattenObjects);
	const sessionId =
		objects
			.map(
				(value) =>
					value.thread_id ??
					value.session_id ??
					value.sessionId ??
					value.chat_id ??
					value.chatId ??
					value.conversation_id,
			)
			.find((value) => typeof value === "string" && value) ?? null;
	const replies = objects.flatMap(replyText).filter(Boolean);
	const toolCalls = objects.flatMap(toolCall).filter(Boolean);
	return { sessionId, reply: replies.at(-1) ?? "", toolCalls };
}

/**
 * Flatten nested event objects so shape-specific values are searchable.
 * - in: Any parsed JSON value.
 * - out: A flat array containing that object and every nested object.
 */
function flattenObjects(value) {
	if (!value || typeof value !== "object") return [];
	return [value, ...Object.values(value).flatMap(flattenObjects)];
}

/**
 * Extract assistant reply text from one known event shape.
 * - in: One flattened harness event object.
 * - out: Zero or more assistant reply strings.
 */
function replyText(value) {
	// Codex final messages.
	if (value.type === "agent_message" && typeof value.text === "string")
		return [value.text];

	// Generic assistant messages used by several JSON event formats.
	if (value.role === "assistant" && typeof value.content === "string")
		return [value.content];
	if (value.role === "assistant" && Array.isArray(value.content)) {
		return value.content
			.filter((part) => part?.type === "text" && typeof part.text === "string")
			.map((part) => part.text);
	}

	// Cursor's final result event.
	if (value.type === "result" && typeof value.result === "string")
		return [value.result];
	return [];
}

/**
 * Normalize one completed tool event from Codex, Cursor, or a generic harness.
 * - in: One flattened harness event object.
 * - out: Zero or one normalized tool call.
 */
function toolCall(value) {
	// Codex shell execution event.
	if (value.type === "command_execution") {
		if (value.status !== "completed") return [];
		return [
			{
				name: "exec_command",
				input: value.command ?? null,
				output: value.aggregated_output ?? value.output ?? null,
			},
		];
	}

	// Cursor wraps completed tools under keys such as readToolCall and
	// shellToolCall. Ignore its matching started event to avoid duplicates.
	if (
		value.type === "tool_call" &&
		value.subtype === "completed" &&
		value.tool_call
	) {
		const entry = Object.entries(value.tool_call).find(([key]) =>
			key.endsWith("ToolCall"),
		);
		if (!entry) return [];
		const [kind, call] = entry;
		return [
			{
				name: kind.slice(0, -"ToolCall".length),
				input: call.args ?? null,
				output: call.result ?? null,
			},
		];
	}

	// Generic fallback for ordinary name/input or name/arguments tool events.
	const name = value.name ?? value.tool_name ?? value.toolName;
	if (typeof name !== "string") return [];
	const type = String(value.type ?? "").toLowerCase();
	if (!type.includes("tool") && !("arguments" in value) && !("input" in value))
		return [];
	return [
		{
			name,
			input: value.input ?? value.arguments ?? null,
			output: value.output ?? value.result ?? null,
		},
	];
}

// =============================================================================
// Decide whether a turn completed
// =============================================================================

/**
 * Decide whether a harness attempt is complete or has an infrastructure issue.
 * - in: Command result, normalized output, and whether a session ID is required.
 * - out: Null for success or a problem containing message and retry permission.
 */
function infrastructureProblem(call, parsed, needsSessionId) {
	if (call.timedOut) {
		return {
			message: `timed out after ${config.timeoutSeconds} seconds`,
			retry: false,
		};
	}
	if (isCapacityFailure(`${call.stdout}\n${call.stderr}`)) {
		return {
			message: "model was at capacity",
			retry: true,
			capacity: true,
		};
	}
	if (call.exitCode !== 0) {
		return {
			message: `command exited with code ${call.exitCode}`,
			retry: true,
		};
	}
	if (!parsed.reply) {
		return {
			message: "response did not contain a final assistant reply",
			retry: true,
		};
	}
	if (needsSessionId && !parsed.sessionId)
		return { message: "response did not contain a session ID", retry: true };
	return null;
}

/**
 * Detect a model-capacity failure that should follow the retry protocol.
 * - in: Combined stdout and stderr text.
 * - out: True for resource exhaustion, overload, or explicit capacity errors.
 */
function isCapacityFailure(text) {
	return /(resource[_ -]exhausted|at capacity|capacity[- ]limited|overloaded)/i.test(
		text,
	);
}

/**
 * Detect an authentication failure in combined harness output.
 * - in: Combined stdout and stderr text.
 * - out: True when the text matches a known authentication failure.
 */
function isAuthenticationFailure(text) {
	return /(\b401\b|unauthorized|authentication failed|not logged in|login required|invalid api key|expired token)/i.test(
		text,
	);
}

/**
 * Fill supported harness argument placeholders without changing prompt text.
 * - in: One argument template and its replacement values.
 * - out: The completed command argument.
 */
function substitute(value, values) {
	return value.replace(
		/\{(repo|model|effort|sessionId|prompt)\}/g,
		(_, key) => values[key],
	);
}

// =============================================================================
// Save the raw record
// =============================================================================

/**
 * Queue an atomic save of the current raw evaluation record.
 * - in: The current module-level record and record path.
 * - out: A promise that resolves after this queued save finishes.
 */
function save() {
	saveQueue = saveQueue.then(async () => {
		const temporaryPath = `${recordPath}.tmp`;
		await writeFile(temporaryPath, `${JSON.stringify(record, null, 2)}\n`);
		await rename(temporaryPath, recordPath);
	});
	return saveQueue;
}

// =============================================================================
// Read and validate inputs
// =============================================================================

/**
 * Parse supported runner command-line options.
 * - in: Command-line arguments after the script name.
 * - out: An object containing optional project and config paths.
 */
function readOptions(args) {
	const parsed = {};
	for (let index = 0; index < args.length; index += 2) {
		const name = args[index];
		const value = args[index + 1];
		if (!["--project", "--config"].includes(name) || !value) {
			throw new Error("Usage: run-eval.mjs [--project PATH] [--config PATH]");
		}
		parsed[name.slice(2)] = value;
	}
	return parsed;
}

/**
 * Reject configs missing the minimum structure required by the runner.
 * - in: The parsed config value.
 * - out: No return value; invalid config throws an error.
 */
function validateConfig(value) {
	if (
		!Number.isInteger(value.runs) ||
		!Number.isInteger(value.concurrency) ||
		value.concurrency < 1 ||
		typeof value.test?.passThreshold !== "number" ||
		value.test.passThreshold <= 0 ||
		value.test.passThreshold > 1 ||
		!Array.isArray(value.test?.turns) ||
		!Array.isArray(value.harnesses)
	) {
		throw new Error("config.json is invalid");
	}
}

// =============================================================================
// Entry point
// =============================================================================

await main();
