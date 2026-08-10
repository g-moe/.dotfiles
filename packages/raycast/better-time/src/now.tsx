import { Clipboard, showToast, Toast } from "@raycast/api";

export default async function Command() {
	const value = String(Date.now());
	await Clipboard.copy(value);
	await showToast({
		style: Toast.Style.Success,
		title: "Copied",
		message: value,
	});
}
