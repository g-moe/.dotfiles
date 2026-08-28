#!/usr/bin/env node

import { readFile, rename, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// =============================================================================
// Main flow
// =============================================================================
//
// Rendering has one straight path: load the run, merge reviewed scores when
// needed, fill the bundled template, write output.md, then finalize the JSON.

const skillRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
let recordPath;
let reviewPath;
let outputPath;
let record;

/**
 * Render or rerender one evaluation report.
 * - 1. Load the record and merge reviewed scores when it is ready.
 * - 2. Render output.md, then finalize output.json and remove review.json.
 */
async function main() {
	const options = readOptions(process.argv.slice(2));
	recordPath = path.resolve(options.record);
	const runDirectory = path.dirname(recordPath);
	reviewPath = path.join(runDirectory, "review.json");
	outputPath = path.join(runDirectory, "output.md");
	record = JSON.parse(await readFile(recordPath, "utf8"));

	const shouldFinalize = record.status === "ready";
	if (shouldFinalize) await prepareFinalRecord();
	else if (record.status !== "completed")
		throw new Error(`Cannot render a record with status "${record.status}"`);

	const template = await readFile(
		path.join(skillRoot, "references", "markdown-output.md"),
		"utf8",
	);
	await writeFile(outputPath, render(template));
	process.stdout.write(`${outputPath}\n`);

	record.reportPath = outputPath;
	await saveJson(recordPath, record);
	if (shouldFinalize) await unlink(reviewPath);
}

// =============================================================================
// Merge reviewed scores and summarize the run
// =============================================================================

/**
 * Merge reviewed scores only after matching every review entry to raw output.
 * - in: The module-level ready record and its sibling review.json.
 * - out: The in-memory record marked completed with scores and summary.
 */
async function prepareFinalRecord() {
	const review = JSON.parse(await readFile(reviewPath, "utf8"));
	if (
		review.outputPath !== recordPath ||
		review.results.length !== record.results.length
	)
		throw new Error("review.json does not match output.json");

	for (const reviewedResult of review.results) {
		const result = record.results[reviewedResult.resultIndex];
		if (!result || reviewedResult.turns.length !== result.turns.length)
			throw new Error("review.json does not match output.json");

		for (const reviewedTurn of reviewedResult.turns) {
			const turn = result.turns[reviewedTurn.turnIndex];
			if (
				!turn ||
				turn.turn !== reviewedTurn.turn ||
				turn.status !== reviewedTurn.status
			)
				throw new Error("review.json does not match output.json");

			if (turn.status === "completed") {
				assertScore(reviewedTurn.score);
				turn.score = reviewedTurn.score;
			} else if (reviewedTurn.score !== null) {
				throw new Error("Only completed turns may be scored");
			}
		}
	}

	assertSummaryFindings(review.summaryFindings);
	record.summary = summarize(record.results);
	record.summaryFindings = review.summaryFindings;
	record.reportPath = outputPath;
	record.status = "completed";
}

/**
 * Count pass, almost, and fail results per complete model run.
 * - in: Every raw result in the evaluation.
 * - out: Totals, scored counts, unscored counts, and percentages.
 */
function summarize(results) {
	const statuses = results.map(runStatus);
	const scored = statuses.filter(Boolean);

	/**
	 * Count scored runs with one status.
	 * - in: Pass, almost, or fail.
	 * - out: Number of scored runs with that status.
	 */
	const count = (status) => scored.filter((value) => value === status).length;

	/**
	 * Convert one count to a scored-run percentage.
	 * - in: A result count.
	 * - out: Percentage rounded to one decimal place.
	 */
	const percentage = (value) =>
		scored.length ? Number(((value / scored.length) * 100).toFixed(1)) : 0;

	return {
		totalRuns: results.length,
		scoredRuns: scored.length,
		unscoredRuns: results.length - scored.length,
		pass: { count: count("pass"), percentage: percentage(count("pass")) },
		almost: {
			count: count("almost"),
			percentage: percentage(count("almost")),
		},
		fail: { count: count("fail"), percentage: percentage(count("fail")) },
	};
}

/**
 * Reduce one model run's turn scores to its run-level status.
 * - in: One result containing every configured turn.
 * - out: Pass, almost, fail, or null when the run is unscored.
 */
function runStatus(result) {
	if (
		result.turns.some(
			(turn) =>
				turn.status === "at-capacity" ||
				turn.status === "infrastructure-failure" ||
				turn.status === "skipped",
		)
	)
		return null;
	if (!result.turns.length || result.turns.some((turn) => !turn.score))
		return null;

	const statuses = result.turns.map((turn) => turn.score.status);
	if (statuses.every((status) => status === "pass")) return "pass";
	if (statuses.every((status) => status === "fail")) return "fail";
	return "almost";
}

// =============================================================================
// Fill the Markdown template
// =============================================================================

/**
 * Fill the generic Markdown template from the evaluation record.
 * - 1. Expand one row per model and one criteria block per configured turn.
 * - 2. Fill report-wide totals and remove template-only comments.
 */
function render(template) {
	const runLabels = {
		pass: "✅",
		almost: "🟡",
		fail: "❌",
		"at-capacity": "⚠️ At Capacity",
		unscored: "⚠️",
	};
	const turnLabels = {
		pass: "✅",
		almost: "🟡",
		fail: "❌",
		"at-capacity": "⚠️",
		unscored: "⚠️",
	};
	const models = groupBy(
		record.results,
		(result) => `${result.harnessId}\0${result.modelLabel}`,
	);

	let output = expand(
		template,
		"MODEL",
		[...models.values()],
		(row, runs) => {
			const multipleRuns = runs.length > 1;
			const runResults = runs
				.map((run) => {
					const status = run.turns.some((turn) => turn.status === "at-capacity")
						? "at-capacity"
						: (runStatus(run) ?? "unscored");
					const label = runLabels[status];
					return multipleRuns ? `Run ${run.run}: ${label}` : label;
				})
				.join("<br>");
			const resultText = multipleRuns
				? `${runResults}<br>Overall: ${modelResult(runs, runLabels)}`
				: runResults;
			const turnText = runs
				.map((run) => {
					const labels = run.turns
						.map(
							(turn) =>
								turnLabels[
									turn.status === "at-capacity"
										? "at-capacity"
										: (turn.score?.status ?? "unscored")
								],
						)
						.join(" ");
					return multipleRuns ? `Run ${run.run}: ${labels}` : labels;
				})
				.join("<br>");
			const replyTimeByRun = runs.map((run) =>
				run.turns.reduce((sum, turn) => sum + turn.replyTimeMs, 0),
			);
			const replyCharsByRun = runs.map((run) =>
				run.turns.reduce((sum, turn) => sum + turn.replyChars, 0),
			);

			return replace(row, {
				HARNESS_LABEL: markdownCell(runs[0].harnessLabel),
				MODEL_LABEL: markdownCell(runs[0].modelLabel),
				RESULT_BY_RUN: resultText,
				TURNS_BY_RUN: turnText,
				AVERAGE_REPLY_TIME: formatTime(average(replyTimeByRun)),
				AVERAGE_REPLY_CHARS: Math.round(
					average(replyCharsByRun),
				).toLocaleString("en-US"),
			});
		},
		"\n",
	);

	output = expand(output, "TURN", record.test.turns, (block, turn, index) =>
		replace(block, {
			TURN_NUMBER: index + 1,
			PASS_CRITERIA: markdownText(turn.criteria.pass),
			ALMOST_CRITERIA: markdownText(turn.criteria.almost),
			FAIL_CRITERIA: markdownText(turn.criteria.fail),
		}),
	);

	output = expand(
		output,
		"FINDING",
		record.summaryFindings,
		(block, finding) =>
			replace(block, {
				FINDING: markdownText(finding),
			}),
		"\n",
	);

	output = replace(output, {
		RUNTIME: markdownText(record.runtime),
		COMMIT: markdownText(record.commit),
		TEST_NAME: markdownText(record.test.name),
		PASS_THRESHOLD_PERCENT: percent(record.test.passThreshold ?? 1, 1),
		SCORED_RUNS: record.summary.scoredRuns,
		TOTAL_RUNS: record.summary.totalRuns,
		PASS_COUNT: record.summary.pass.count,
		PASS_PERCENT: percent(record.summary.pass.count, record.summary.scoredRuns),
		ALMOST_COUNT: record.summary.almost.count,
		ALMOST_PERCENT: percent(
			record.summary.almost.count,
			record.summary.scoredRuns,
		),
		FAIL_COUNT: record.summary.fail.count,
		FAIL_PERCENT: percent(record.summary.fail.count, record.summary.scoredRuns),
		TOTAL_PERCENT: record.summary.scoredRuns ? "100%" : "0.0%",
	});

	return (
		output
			.replace(/<!--[\s\S]*?-->/g, "")
			.replace(/\n{3,}/g, "\n\n")
			.trim() + "\n"
	);
}

/**
 * Require five to ten short, single-line findings from the scoring model.
 * - in: The reviewed summary findings.
 * - out: No return value; invalid findings throw an error.
 */
function assertSummaryFindings(findings) {
	if (
		!Array.isArray(findings) ||
		findings.length < 5 ||
		findings.length > 10 ||
		findings.some(
			(finding) =>
				typeof finding !== "string" ||
				!finding.trim() ||
				finding.includes("\n"),
		)
	)
		throw new Error("Summary findings must contain 5–10 nonempty lines");
}

/**
 * Summarize repeated runs for one harness/model using the configured threshold.
 * - in: Runs for one harness/model and the report's status labels.
 * - out: Overall label plus the exact passing/scored run rate.
 */
function modelResult(runs, labels) {
	const scored = runs.map(runStatus).filter(Boolean);
	if (!scored.length)
		return runs.some((run) =>
			run.turns.some((turn) => turn.status === "at-capacity"),
		)
			? labels["at-capacity"]
			: labels.unscored;
	const passes = scored.filter((status) => status === "pass").length;
	const status =
		passes / scored.length >= (record.test.passThreshold ?? 1)
			? "pass"
			: scored.every((value) => value === "fail")
				? "fail"
				: "almost";
	return `${labels[status]} ${passes}/${scored.length} (${percent(passes, scored.length)})`;
}

/**
 * Repeat one marked template block for a list of values.
 * - in: Template, marker name, items, one item renderer, and row separator.
 * - out: The template with that marked block expanded.
 */
function expand(template, name, items, renderItem, separator = "\n\n") {
	const pattern = new RegExp(
		`<!-- BEGIN ${name} -->([\\s\\S]*?)<!-- END ${name} -->`,
	);
	const match = template.match(pattern);
	if (!match) throw new Error(`Template is missing ${name} markers`);
	return template.replace(
		match[0],
		items
			.map((item, index) => renderItem(match[1], item, index).trim())
			.join(separator),
	);
}

/**
 * Replace uppercase template placeholders from a value map.
 * - in: Template text and keyed replacement values.
 * - out: Template text with recognized placeholders replaced.
 */
function replace(template, values) {
	return template.replace(/\{\{([A-Z_]+)\}\}/g, (match, key) =>
		key in values ? values[key] : match,
	);
}

// =============================================================================
// Small display helpers
// =============================================================================

/**
 * Group values while preserving their first-seen key order.
 * - in: Values and a function that returns each value's group key.
 * - out: A map from each key to its ordered values.
 */
function groupBy(values, keyFor) {
	const groups = new Map();
	for (const value of values) {
		const key = keyFor(value);
		if (!groups.has(key)) groups.set(key, []);
		groups.get(key).push(value);
	}
	return groups;
}

/**
 * Escape dynamic text used inside one Markdown table cell.
 * - in: Any value rendered inside a table cell.
 * - out: Text with pipes escaped and line breaks converted to <br> separators.
 */
function markdownCell(value) {
	return markdownText(value).replaceAll("|", "\\|").replaceAll("\n", "<br>");
}

/**
 * Keep dynamic Markdown text on its intended line.
 * - in: Any value rendered as report text.
 * - out: A string with carriage returns removed.
 */
function markdownText(value) {
	return String(value).replaceAll("\r", "");
}

/**
 * Average a list of per-run totals.
 * - in: Numeric totals for every run of one harness/model pair.
 * - out: Their arithmetic mean, or zero when no runs exist.
 */
function average(values) {
	return values.length
		? values.reduce((sum, value) => sum + value, 0) / values.length
		: 0;
}

/**
 * Format a count as a percentage with one decimal place.
 * - in: Count and denominator.
 * - out: A percentage string, or 0.0% for an empty denominator.
 */
function percent(count, total) {
	return `${total ? ((count / total) * 100).toFixed(1) : "0.0"}%`;
}

/**
 * Format elapsed milliseconds for the results table.
 * - in: Elapsed time in milliseconds.
 * - out: Milliseconds below one second, otherwise seconds with one decimal.
 */
function formatTime(milliseconds) {
	return milliseconds < 1000
		? `${milliseconds}ms`
		: `${(milliseconds / 1000).toFixed(1)}s`;
}

// =============================================================================
// Validate scores and save the final record
// =============================================================================

/**
 * Require a valid status and nonempty reason for one completed turn.
 * - in: A reviewed turn score.
 * - out: No return value; invalid scores throw an error.
 */
function assertScore(score) {
	if (
		!score ||
		!["pass", "almost", "fail"].includes(score.status) ||
		typeof score.reason !== "string" ||
		!score.reason.trim()
	)
		throw new Error(
			"Every completed turn needs a pass/almost/fail score and reason",
		);
}

/**
 * Atomically replace one JSON file.
 * - in: Destination path and serializable value.
 * - out: A promise that resolves after the temporary file is renamed.
 */
async function saveJson(file, value) {
	const temporary = `${file}.tmp`;
	await writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`);
	await rename(temporary, file);
}

// =============================================================================
// Read command-line input
// =============================================================================

/**
 * Parse the renderer's required record option.
 * - in: Command-line arguments after the script name.
 * - out: An object containing the record path.
 */
function readOptions(args) {
	const parsed = {};
	for (let index = 0; index < args.length; index += 2) {
		const name = args[index];
		const value = args[index + 1];
		if (name !== "--record" || !value)
			throw new Error("Usage: render-report.mjs --record PATH");
		parsed[name.slice(2)] = value;
	}
	if (!parsed.record) throw new Error("Usage: render-report.mjs --record PATH");
	return parsed;
}

// =============================================================================
// Entry point
// =============================================================================

await main();
