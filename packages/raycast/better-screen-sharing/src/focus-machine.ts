import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
	parseDialogOutcome,
	parseFocusResult,
	runConnectionsControlFlow,
	runMachineControlFlow,
	type FocusResult,
} from "./control-flow";

/**
 * Expected control flows
 *
 * Connections:
 * - All Connections open: focus and raise that window.
 * - Screen Sharing closed or window missing: launch the app, ask its native
 *   Connections command to create the window, then focus it.
 *
 * Machine:
 * - Viewer open: select its native Window menu item so macOS also switches Space.
 * - Viewer closed: open vnc://<address>. Apple/Keychain supplies saved credentials;
 *   poll until the viewer exists, accepting Sign In once and the default sharing
 *   type in either order. It never reads or types a username or password.
 */

const run = promisify(execFile);

const focusScript = String.raw`
ObjC.import("ApplicationServices");
ObjC.import("AppKit");

function attribute(element, name) {
  const value = $();
  return Number($.AXUIElementCopyAttributeValue(element, $(name), value)) === 0 ? value : null;
}

function children(element) {
  const value = element && attribute(element, "AXChildren");
  const result = [];
  if (value) for (let index = 0; index < value.count; index++) result.push(value.objectAtIndex(index));
  return result;
}

function title(element) {
  const value = attribute(element, "AXTitle");
  return value ? String(ObjC.unwrap(value)) : "";
}

function run(argv) {
  const name = argv[0];
  if (!$.AXIsProcessTrusted()) return "accessibility";

  const processes = $.NSRunningApplication.runningApplicationsWithBundleIdentifier("com.apple.ScreenSharing");
  if (Number(processes.count) === 0) return "not-open";

  const process = processes.firstObject;
  const app = $.AXUIElementCreateApplication(process.processIdentifier);
  if (name === "All Connections") {
    const windows = attribute(app, "AXWindows");
    for (let index = 0; windows && index < windows.count; index++) {
      const window = windows.objectAtIndex(index);
      if (title(window) === name) {
        process.activateWithOptions($.NSApplicationActivateAllWindows | $.NSApplicationActivateIgnoringOtherApps);
        $.AXUIElementSetAttributeValue(window, $("AXMain"), true);
        $.AXUIElementSetAttributeValue(window, $("AXFocused"), true);
        return Number($.AXUIElementPerformAction(window, $("AXRaise"))) === 0 ? "focused" : "not-open";
      }
    }
  }

  const menuBar = attribute(app, "AXMenuBar");
  const windowItem = children(menuBar).find((item) => title(item) === "Window");
  const windowMenu = children(windowItem).find((item) => {
    const role = attribute(item, "AXRole");
    return role && String(ObjC.unwrap(role)) === "AXMenu";
  });
  const items = children(windowMenu);
  const exact = items.find((item) => title(item) === name);
  const prefixes = items.filter((item) => title(item).toLowerCase().startsWith(name.toLowerCase()));
  const machine = exact || (prefixes.length === 1 ? prefixes[0] : null);
  if (!machine) return "not-open";

  return Number($.AXUIElementPerformAction(machine, $("AXPress"))) === 0 ? "focused" : "not-open";
}
`;

const dialogScript = String.raw`
ObjC.import("ApplicationServices");
ObjC.import("AppKit");

function attribute(element, name) {
  const value = $();
  return Number($.AXUIElementCopyAttributeValue(element, $(name), value)) === 0 ? value : null;
}

function children(element) {
  const value = element && attribute(element, "AXChildren");
  const result = [];
  if (value) for (let index = 0; index < value.count; index++) result.push(value.objectAtIndex(index));
  const sections = element && attribute(element, "AXSections");
  if (sections) {
    for (let index = 0; index < sections.count; index++) {
      const section = sections.objectAtIndex(index).objectForKey("SectionObject");
      if (section) result.push(section);
    }
  }
  return result;
}

function descendants(element) {
  return children(element).flatMap((child) => [child, ...descendants(child)]);
}

function text(element) {
  const value = attribute(element, "AXValue") || attribute(element, "AXTitle") || attribute(element, "AXDescription");
  return value ? String(ObjC.unwrap(value)) : "";
}

function run(argv) {
  const address = argv[0];
  const allowSignIn = argv[1] === "1";
  const allowSharingType = argv[2] === "1";
  const processes = $.NSRunningApplication.runningApplicationsWithBundleIdentifier("com.apple.ScreenSharing");
  if (Number(processes.count) === 0) return "waiting";

  const app = $.AXUIElementCreateApplication(processes.firstObject.processIdentifier);
  const windows = children(app).map((window) => descendants(window));
  const signIn = windows.find((elements) =>
    elements.some((element) => text(element).includes(address)) &&
    elements.some((element) => text(element) === "Sign In")
  );
  const sharingType = windows.find((elements) =>
    elements.some((element) => text(element) === "Select Screen Sharing Type:")
  );

  if (signIn && allowSignIn) {
    const button = signIn.find((element) => text(element) === "Sign In");
    if (!button || Number($.AXUIElementPerformAction(button, $("AXPress"))) !== 0) {
      throw new Error("Could not accept Screen Sharing Sign In dialog");
    }
    return "pressed-sign-in";
  }

  if (sharingType && allowSharingType) {
    const button = sharingType.find((element) => text(element) === "Continue");
    if (!button || Number($.AXUIElementPerformAction(button, $("AXPress"))) !== 0) {
      throw new Error("Could not accept Screen Sharing type dialog");
    }
    return "pressed-sharing-type";
  }

  return "waiting";
}
`;

async function focusWindow(name: string): Promise<FocusResult> {
	const { stdout } = await run("/usr/bin/osascript", [
		"-l",
		"JavaScript",
		"-e",
		focusScript,
		"--",
		name,
	]);
	return parseFocusResult(stdout);
}

export async function openOrFocusMachine(
	name: string,
	address: string,
): Promise<void> {
	return runMachineControlFlow(name, address, {
		focusWindow,
		openUrl: async (url) => {
			await run("/usr/bin/open", [url]);
		},
		stepDialog: async (dialogAddress, allowed) => {
			const { stdout } = await run("/usr/bin/osascript", [
				"-l",
				"JavaScript",
				"-e",
				dialogScript,
				"--",
				dialogAddress,
				allowed.signIn ? "1" : "0",
				allowed.sharingType ? "1" : "0",
			]);
			return parseDialogOutcome(stdout);
		},
		activateApp: activateScreenSharing,
		sleep: async () => {
			await new Promise((resolve) => setTimeout(resolve, 100));
		},
	});
}

export async function openConnections(): Promise<void> {
	return runConnectionsControlFlow({
		focusWindow,
		openApp: activateScreenSharing,
		sleep: async () => {
			await new Promise((resolve) => setTimeout(resolve, 100));
		},
	});
}

async function activateScreenSharing(): Promise<void> {
	await run("/usr/bin/open", [
		"/System/Applications/Utilities/Screen Sharing.app",
	]);
}
