export type Machine = { name: string; address: string };

export function configuredMachines(
	preferences: Preferences.Connections,
): Machine[] {
	return [
		{ name: preferences.machine1Name, address: preferences.machine1Address },
		{ name: preferences.machine2Name, address: preferences.machine2Address },
		{ name: preferences.machine3Name, address: preferences.machine3Address },
		{ name: preferences.machine4Name, address: preferences.machine4Address },
		{ name: preferences.machine5Name, address: preferences.machine5Address },
	]
		.map(({ name, address }) => ({
			name: name?.trim(),
			address: address?.trim(),
		}))
		.filter((machine): machine is Machine =>
			Boolean(machine.name && machine.address),
		);
}
