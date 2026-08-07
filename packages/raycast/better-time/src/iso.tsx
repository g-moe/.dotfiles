import { Action, ActionPanel, Detail, LaunchProps } from "@raycast/api";
import { Time } from "./time.ts";

export default function Command(
	props: LaunchProps<{ arguments: Arguments.Iso }>,
) {
	const result = Time.toIso(props.arguments.timestamp);

	if (!result.ok) {
		return <Detail markdown={`# Invalid input\n\n${result.error}`} />;
	}

	return (
		<Detail
			markdown={`# ${result.iso}\n\n\`${result.ms}\``}
			actions={
				<ActionPanel>
					<Action.CopyToClipboard title="Copy ISO" content={result.iso} />
					<Action.CopyToClipboard
						title="Copy Unix ms"
						content={String(result.ms)}
					/>
				</ActionPanel>
			}
		/>
	);
}
