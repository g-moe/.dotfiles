import {
	Action,
	ActionPanel,
	closeMainWindow,
	getPreferenceValues,
	Icon,
	List,
	PopToRootType,
	showHUD,
} from "@raycast/api";
import { openConnections, openOrFocusMachine } from "./focus-machine";
import { configuredMachines } from "./machines";

async function runAction(action: () => Promise<void>): Promise<void> {
	try {
		await action();
		await closeRaycast();
	} catch (error) {
		await showHUD(error instanceof Error ? error.message : String(error));
	}
}

function closeRaycast(): Promise<void> {
	return closeMainWindow({
		clearRootSearch: true,
		popToRootType: PopToRootType.Immediate,
	});
}

export default function Command() {
	const preferences = getPreferenceValues<Preferences.Connections>();
	const machines = configuredMachines(preferences);

	return (
		<List>
			<List.Section>
				<List.Item
					title="Connections"
					icon={Icon.AppWindowList}
					actions={
						<ActionPanel>
							<Action
								title="Open Screen Sharing"
								onAction={() => runAction(openConnections)}
							/>
						</ActionPanel>
					}
				/>
			</List.Section>
			<List.Section>
				{machines.map(({ name, address }) => (
					<List.Item
						key={name}
						title={name}
						icon={Icon.Desktop}
						actions={
							<ActionPanel>
								<Action
									title={`Open or Focus ${name}`}
									onAction={() =>
										runAction(() => openOrFocusMachine(name, address))
									}
								/>
							</ActionPanel>
						}
					/>
				))}
			</List.Section>
		</List>
	);
}
