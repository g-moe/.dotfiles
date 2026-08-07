import { Clipboard, showToast, Toast } from "@raycast/api";
import { Time } from "./time.ts";

export default async function Command() {
	const value = String(Time.now());
	await Clipboard.copy(value);
	await showToast({
		style: Toast.Style.Success,
		title: "Copied",
		message: value,
	});
}
