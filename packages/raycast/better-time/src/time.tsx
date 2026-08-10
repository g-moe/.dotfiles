import { Action, ActionPanel, Icon, List } from "@raycast/api";
import { useMemo, useState } from "react";
import { Time, type TimeFormat } from "./time-values.ts";

const localTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
const timeZones = Array.from(
	new Set(["UTC", localTimeZone, ...Intl.supportedValuesOf("timeZone")]),
).sort((left, right) => left.localeCompare(right));

function TimeZonePicker(props: {
	timeZone: string;
	onChange: (timeZone: string) => void;
}) {
	return (
		<List.Dropdown
			tooltip="Select Time Zone"
			value={props.timeZone}
			onChange={props.onChange}
		>
			{timeZones.map((timeZone) => (
				<List.Dropdown.Item key={timeZone} value={timeZone} title={timeZone} />
			))}
		</List.Dropdown>
	);
}

function SetToNowAction(props: { onAction: () => void }) {
	return (
		<Action
			title="Set to Now"
			icon={Icon.Clock}
			shortcut={{ modifiers: ["cmd"], key: "n" }}
			onAction={props.onAction}
		/>
	);
}

function FormatItem(props: {
	format: TimeFormat;
	timeZone: string;
	onSetToNow: () => void;
}) {
	return (
		<List.Item
			id={props.format.id}
			title={props.format.label}
			subtitle={{
				value: props.format.utc,
				tooltip: `UTC: ${props.format.utc}`,
			}}
			accessories={[
				{
					text: props.format.zoned,
					tooltip: `${props.timeZone}: ${props.format.zoned}`,
				},
			]}
			actions={
				<ActionPanel>
					<Action.CopyToClipboard
						title={`Copy UTC ${props.format.label}`}
						content={props.format.utc}
					/>
					<Action.CopyToClipboard
						title={`Copy ${props.timeZone} ${props.format.label}`}
						content={props.format.zoned}
					/>
					<SetToNowAction onAction={props.onSetToNow} />
				</ActionPanel>
			}
		/>
	);
}

export default function Command() {
	const [timestamp, setTimestamp] = useState(() => String(Date.now()));
	const [timeZone, setTimeZone] = useState(localTimeZone);
	const [selectedItemId, setSelectedItemId] = useState("date-time");
	const parsed = useMemo(() => Time.parseUnixMs(timestamp), [timestamp]);
	const setToNow = () => setTimestamp(String(Date.now()));
	const formats = parsed.ok ? Time.formats(parsed.value, timeZone) : [];

	return (
		<List
			filtering={false}
			navigationTitle="Time"
			selectedItemId={selectedItemId}
			onSelectionChange={(id) => {
				if (id && id !== "column-headings") setSelectedItemId(id);
			}}
			searchBarPlaceholder="Unix milliseconds"
			searchText={timestamp}
			onSearchTextChange={setTimestamp}
			searchBarAccessory={
				<TimeZonePicker timeZone={timeZone} onChange={setTimeZone} />
			}
			actions={
				<ActionPanel>
					<SetToNowAction onAction={setToNow} />
				</ActionPanel>
			}
		>
			{parsed.ok ? (
				<List.Section>
					<List.Item
						id="column-headings"
						title="UTC"
						accessories={[{ text: timeZone }]}
					/>
					{formats.map((format) => (
						<FormatItem
							key={format.id}
							format={format}
							timeZone={timeZone}
							onSetToNow={setToNow}
						/>
					))}
				</List.Section>
			) : (
				<List.EmptyView
					icon={Icon.XMarkCircle}
					title="Invalid Unix milliseconds"
					description={parsed.error}
				/>
			)}
		</List>
	);
}
