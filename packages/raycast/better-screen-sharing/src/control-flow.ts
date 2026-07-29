export type FocusResult = "accessibility" | "focused" | "not-open";
export type DialogOutcome =
	| "waiting"
	| "pressed-sign-in"
	| "pressed-sharing-type";

type MachineDependencies = {
	focusWindow: (name: string) => Promise<FocusResult>;
	openUrl: (url: string) => Promise<void>;
	stepDialog: (
		address: string,
		allowed: { signIn: boolean; sharingType: boolean },
	) => Promise<DialogOutcome>;
	activateApp: () => Promise<void>;
	sleep: () => Promise<void>;
};

type ConnectionsDependencies = {
	focusWindow: (name: string) => Promise<FocusResult>;
	openApp: () => Promise<void>;
	sleep: () => Promise<void>;
};

function requireAccessibility(result: FocusResult): void {
	if (result === "accessibility")
		throw new Error("Raycast needs Accessibility access");
}

export function parseFocusResult(output: string): FocusResult {
	const value = output.trim();
	if (value === "accessibility" || value === "focused" || value === "not-open")
		return value;
	throw new Error(`Unexpected focus adapter output: ${JSON.stringify(value)}`);
}

export function parseDialogOutcome(output: string): DialogOutcome {
	const value = output.trim();
	if (
		value === "waiting" ||
		value === "pressed-sign-in" ||
		value === "pressed-sharing-type"
	)
		return value;
	throw new Error(`Unexpected dialog adapter output: ${JSON.stringify(value)}`);
}

export async function runMachineControlFlow(
	name: string,
	address: string,
	dependencies: MachineDependencies,
): Promise<void> {
	let result = await dependencies.focusWindow(name);
	requireAccessibility(result);
	if (result === "focused") {
		await dependencies.activateApp();
		return;
	}

	await dependencies.openUrl(`vnc://${address}`);
	let signInPressed = false;
	let sharingTypePressed = false;

	for (let attempt = 0; attempt < 50; attempt++) {
		result = await dependencies.focusWindow(name);
		requireAccessibility(result);
		if (result === "focused") {
			await dependencies.activateApp();
			return;
		}

		const dialog = await dependencies.stepDialog(address, {
			signIn: !signInPressed,
			sharingType: !sharingTypePressed,
		});
		if (dialog === "pressed-sharing-type") {
			sharingTypePressed = true;
		} else if (dialog === "pressed-sign-in") {
			signInPressed = true;
		}
		await dependencies.sleep();
	}

	throw new Error(`Could not connect to ${name}`);
}

export async function runConnectionsControlFlow(
	dependencies: ConnectionsDependencies,
): Promise<void> {
	let result = await dependencies.focusWindow("All Connections");
	requireAccessibility(result);
	if (result === "focused") return;

	await dependencies.openApp();
	for (let attempt = 0; attempt < 50; attempt++) {
		result = await dependencies.focusWindow("All Connections");
		requireAccessibility(result);
		if (result === "focused") return;
		requireAccessibility(await dependencies.focusWindow("Connections"));
		await dependencies.sleep();
	}

	throw new Error("Could not open Screen Sharing connections");
}
