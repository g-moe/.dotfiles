import { randomUUID } from "node:crypto";
import type * as vscode from "vscode";

import type { Terminal, TerminalHost, TerminalState } from "./contracts";

const OWNER_ENV = "BETTER_VSCODE_TERMINAL_ID";
const TERMINAL_NAME = "terminal";

// Owns shell identity and startup. Editor placement belongs to editor.ts.
export class TerminalService<T extends Terminal> {
	private state: TerminalState;
	private terminal?: T;
	private terminalReady = false;
	private readonly closedProcesses = new WeakSet<T>();
	private pending?: Promise<T>;
	private readonly closed: vscode.Disposable;
	private readonly controller = new AbortController();

	constructor(
		private readonly host: TerminalHost<T>,
		private readonly timeoutMs = 5000,
	) {
		this.state = host.load() ?? { ownerId: randomUUID() };

		this.closed = host.onClose((terminal) => {
			if (terminal === this.terminal) {
				this.terminal = undefined;
				this.terminalReady = false;
				this.state = { ownerId: this.state.ownerId };

				void Promise.resolve(host.save(this.state)).catch(console.error);
			}
		});
	}

	get signal(): AbortSignal {
		return this.controller.signal;
	}

	// Share one startup operation when several commands arrive together.
	getTerminal(): Promise<T> {
		if (!this.pending) {
			this.pending = this.acquire().finally(() => {
				this.pending = undefined;
			});
		}

		return this.pending;
	}

	dispose() {
		this.controller.abort();
		this.closed.dispose();
	}

	private async acquire(): Promise<T> {
		this.signal.throwIfAborted();
		await this.checkClosedProcesses();

		const ready = this.getReadyTerminal();

		if (ready) {
			return ready;
		}

		return this.prepareTerminal();
	}

	private getReadyTerminal(): T | undefined {
		const terminal = this.terminal;

		if (!terminal || !this.terminalReady || !this.isLive(terminal)) {
			return undefined;
		}

		this.assertUniqueName(terminal.name, terminal);

		return terminal;
	}

	private async prepareTerminal(): Promise<T> {
		// Save ownership before creation so a failed startup can reuse its shell.
		this.terminalReady = false;
		await this.wait(this.host.save(this.state));

		let terminal = await this.findOwnedTerminal();

		if (!terminal) {
			terminal = this.createTerminal();
		}

		this.assertUniqueName(terminal.name, terminal);
		this.signal.throwIfAborted();
		this.terminal = terminal;
		await this.saveProcess(terminal);

		// Only a successful save permits reuse without repeating startup.
		this.terminalReady = true;

		return terminal;
	}

	private async checkClosedProcesses(): Promise<void> {
		// VS Code can still list a closed shell after a panel/editor move.
		for (const terminal of this.host.terminals()) {
			const mayBeOwned =
				terminal === this.terminal ||
				terminal.name === (this.terminal?.name ?? TERMINAL_NAME) ||
				this.hasOwnershipMarker(terminal);

			if (!mayBeOwned) {
				continue;
			}

			const id = await this.wait(terminal.processId);

			// Missing process information does not prove that the shell has closed.
			if (id !== undefined && !this.host.processAlive(id)) {
				this.closedProcesses.add(terminal);
			}
		}
	}

	private async findOwnedTerminal(): Promise<T | undefined> {
		const terminals = this.host
			.terminals()
			.filter((terminal) => this.isLive(terminal));
		const marked = terminals.filter((terminal) =>
			this.hasOwnershipMarker(terminal),
		);

		if (marked.length === 1) {
			return marked[0];
		}

		const restored = await this.findRestoredTerminal(terminals);

		if (restored) {
			return restored;
		}

		if (marked.length > 1) {
			throw new Error(
				"More than one terminal has the ownership marker. Close the extra terminal and try again.",
			);
		}

		return undefined;
	}

	private async findRestoredTerminal(
		terminals: readonly T[],
	): Promise<T | undefined> {
		const saved = this.state.process;

		if (!saved) {
			return undefined;
		}

		// Reload can remove the ownership marker. PID alone is not safe to reuse.
		for (const terminal of terminals) {
			const id = await this.wait(terminal.processId);

			if (id !== saved.id) {
				continue;
			}

			const start = await this.wait(this.host.processStart(id));

			if (start === saved.start) {
				return terminal;
			}
		}

		return undefined;
	}

	private createTerminal(): T {
		this.assertUniqueName(TERMINAL_NAME);
		this.signal.throwIfAborted();

		return this.host.create({
			name: TERMINAL_NAME,
			env: { [OWNER_ENV]: this.state.ownerId },
			location: { viewColumn: 1 },
		});
	}

	private async saveProcess(terminal: T): Promise<void> {
		const id = await this.wait(terminal.processId);
		const start =
			id === undefined
				? undefined
				: await this.wait(this.host.processStart(id));

		this.assertLive(terminal);
		this.state = {
			ownerId: this.state.ownerId,
			process: id !== undefined && start ? { id, start } : undefined,
		};
		await this.wait(this.host.save(this.state));
		this.assertLive(terminal);
	}

	private hasOwnershipMarker(terminal: T) {
		const options = terminal.creationOptions;

		return "env" in options && options.env?.[OWNER_ENV] === this.state.ownerId;
	}

	private isLive(terminal: T) {
		return (
			!this.closedProcesses.has(terminal) &&
			terminal.exitStatus === undefined &&
			this.host.terminals().includes(terminal)
		);
	}

	private assertLive(terminal: T) {
		this.signal.throwIfAborted();

		if (!this.isLive(terminal)) {
			throw new Error("The terminal closed. Run the command again.");
		}
	}

	// The stable tab API exposes titles, not terminal IDs. A duplicate title
	// would make editor commands ambiguous even when the shell identity is known.
	private assertUniqueName(name: string, owned?: T) {
		if (
			this.host
				.terminals()
				.some(
					(terminal) =>
						terminal !== owned &&
						this.isLive(terminal) &&
						terminal.name === name,
				)
		) {
			throw new Error(
				"Two terminals have the same name, or the existing terminal cannot be identified. Rename or close the other terminal and try again.",
			);
		}
	}

	// Startup and state storage can stall. All exit paths release the timeout
	// and abort listener, including extension disposal during a pending request.
	private wait<R>(operation: PromiseLike<R>): Promise<R> {
		this.signal.throwIfAborted();

		return new Promise((resolve, reject) => {
			const abort = () => {
				finish();
				reject(new Error("The terminal service stopped."));
			};
			const timer = setTimeout(() => {
				finish();
				reject(
					new Error(
						"The terminal did not become ready in time. Run the command again.",
					),
				);
			}, this.timeoutMs);
			const finish = () => {
				clearTimeout(timer);
				this.signal.removeEventListener("abort", abort);
			};

			this.signal.addEventListener("abort", abort, { once: true });
			Promise.resolve(operation).then(
				(value) => {
					finish();
					resolve(value);
				},
				(error) => {
					finish();
					reject(error);
				},
			);
		});
	}
}
