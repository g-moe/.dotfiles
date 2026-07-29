import assert from "node:assert/strict";
import test from "node:test";
import {
	parseDialogOutcome,
	parseFocusResult,
	runConnectionsControlFlow,
	runMachineControlFlow,
	type DialogOutcome,
	type FocusResult,
} from "../src/control-flow.ts";

test("adapter parsers accept only their finite outputs", () => {
	assert.equal(parseFocusResult("focused\n"), "focused");
	assert.equal(parseFocusResult("not-open"), "not-open");
	assert.equal(parseFocusResult("accessibility"), "accessibility");
	assert.equal(parseDialogOutcome("pressed-sign-in\n"), "pressed-sign-in");
	assert.equal(
		parseDialogOutcome("pressed-sharing-type"),
		"pressed-sharing-type",
	);
	assert.equal(parseDialogOutcome("waiting"), "waiting");
	assert.throws(() => parseFocusResult(""), /Unexpected focus adapter/);
	assert.throws(
		() => parseDialogOutcome("pressed"),
		/Unexpected dialog adapter/,
	);
});

function machineDependencies(
	focus: FocusResult[],
	dialogs: DialogOutcome[] = [],
) {
	const events: string[] = [];
	return {
		events,
		dependencies: {
			focusWindow: async (name: string) => {
				events.push(`focus:${name}`);
				return focus.shift() ?? "not-open";
			},
			openUrl: async (url: string) => void events.push(`open:${url}`),
			stepDialog: async (
				_address: string,
				allowed: { signIn: boolean; sharingType: boolean },
			) => {
				const dialog = dialogs.shift() ?? "waiting";
				events.push(
					`step:${dialog}:sign-in=${allowed.signIn}:sharing-type=${allowed.sharingType}`,
				);
				return dialog;
			},
			activateApp: async () => void events.push("activate"),
			sleep: async () => void events.push("sleep"),
		},
	};
}

test("an open machine focuses and activates without opening or signing in", async () => {
	const { events, dependencies } = machineDependencies(["focused"]);
	await runMachineControlFlow("Office Mac", "office-mac.local", dependencies);

	assert.deepEqual(events, ["focus:Office Mac", "activate"]);
});

test("a closed machine handles sharing type then Sign In exactly once", async () => {
	const { events, dependencies } = machineDependencies(
		["not-open", "not-open", "not-open", "focused"],
		["pressed-sharing-type", "pressed-sign-in"],
	);
	await runMachineControlFlow("Office Mac", "office-mac.local", dependencies);

	assert.deepEqual(events, [
		"focus:Office Mac",
		"open:vnc://office-mac.local",
		"focus:Office Mac",
		"step:pressed-sharing-type:sign-in=true:sharing-type=true",
		"sleep",
		"focus:Office Mac",
		"step:pressed-sign-in:sign-in=true:sharing-type=false",
		"sleep",
		"focus:Office Mac",
		"activate",
	]);
});

test("a closed machine handles a direct Sign In exactly once", async () => {
	const { events, dependencies } = machineDependencies(
		["not-open", "not-open", "not-open", "focused"],
		["pressed-sign-in", "waiting"],
	);
	await runMachineControlFlow("Home PC", "192.168.1.100", dependencies);

	assert.equal(
		events.filter((event) => event.startsWith("step:pressed-sign-in")).length,
		1,
	);
	assert.ok(events.includes("step:waiting:sign-in=false:sharing-type=true"));
	assert.deepEqual(events.slice(-2), ["focus:Home PC", "activate"]);
});

test("a closed machine handles Sign In then sharing type", async () => {
	const { events, dependencies } = machineDependencies(
		["not-open", "not-open", "not-open", "focused"],
		["pressed-sign-in", "pressed-sharing-type"],
	);
	await runMachineControlFlow("Office Mac", "office-mac.local", dependencies);

	assert.ok(
		events.includes(
			"step:pressed-sharing-type:sign-in=false:sharing-type=true",
		),
	);
	assert.deepEqual(events.slice(-2), ["focus:Office Mac", "activate"]);
});

test("a closed machine succeeds when the viewer appears without a dialog", async () => {
	const { events, dependencies } = machineDependencies(
		["not-open", "not-open", "focused"],
		["waiting"],
	);
	await runMachineControlFlow("Office Mac", "office-mac.local", dependencies);

	assert.deepEqual(events, [
		"focus:Office Mac",
		"open:vnc://office-mac.local",
		"focus:Office Mac",
		"step:waiting:sign-in=true:sharing-type=true",
		"sleep",
		"focus:Office Mac",
		"activate",
	]);
});

test("a closed machine reports a bounded dialog timeout", async () => {
	const { events, dependencies } = machineDependencies([]);
	await assert.rejects(
		runMachineControlFlow("Office Mac", "office-mac.local", dependencies),
		/Could not connect/,
	);

	assert.equal(
		events.filter((event) => event.startsWith("step:waiting")).length,
		50,
	);
	assert.equal(events.includes("activate"), false);
});

test("missing Accessibility access never opens a machine", async () => {
	const { events, dependencies } = machineDependencies(["accessibility"]);
	await assert.rejects(
		runMachineControlFlow("Office Mac", "office-mac.local", dependencies),
		/Accessibility/,
	);

	assert.deepEqual(events, ["focus:Office Mac"]);
});

test("Connections focuses an existing All Connections window without launching", async () => {
	let launched = false;
	await runConnectionsControlFlow({
		focusWindow: async () => "focused",
		openApp: async () => void (launched = true),
		sleep: async () => undefined,
	});
	assert.equal(launched, false);
});

test("Connections launches Screen Sharing and waits for All Connections", async () => {
	const focused: string[] = [];
	const results: FocusResult[] = ["not-open", "not-open", "focused"];
	let launched = false;

	await runConnectionsControlFlow({
		focusWindow: async (name) => {
			focused.push(name);
			return name === "All Connections"
				? (results.shift() ?? "focused")
				: "not-open";
		},
		openApp: async () => void (launched = true),
		sleep: async () => undefined,
	});

	assert.equal(launched, true);
	assert.deepEqual(focused, [
		"All Connections",
		"All Connections",
		"Connections",
		"All Connections",
	]);
});

test("Connections reports when All Connections never appears", async () => {
	await assert.rejects(
		runConnectionsControlFlow({
			focusWindow: async () => "not-open",
			openApp: async () => undefined,
			sleep: async () => undefined,
		}),
		/Could not open Screen Sharing connections/,
	);
});
