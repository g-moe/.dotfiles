import { spawnSync } from "node:child_process";

type Mode = "normal" | "server";

type ModeSetting = {
	description: string;
	normal: string;
	server: string;
};

const PMSET_SETTINGS = {
	sleep: {
		description:
			"System sleep timer in minutes (0 = never sleep; positive number = minutes before sleep).",
		normal: "0",
		server: "0",
	},
	displaysleep: {
		description:
			"Display sleep timer in minutes (0 = never turn display off; positive number = minutes before display sleep).",
		normal: "0",
		server: "0",
	},
	disksleep: {
		description:
			"Disk sleep timer in minutes (0 = never sleep disks; positive number = minutes before disk sleep).",
		normal: "10",
		server: "10",
	},
	womp: {
		description:
			"Wake for network access / Wake on Magic Packet (1 = enabled, 0 = disabled).",
		normal: "1",
		server: "1",
	},
	powernap: {
		description:
			"Power Nap background tasks while sleeping (1 = enabled, 0 = disabled).",
		normal: "1",
		server: "1",
	},
	tcpkeepalive: {
		description:
			"Maintain TCP sessions during sleep (1 = keep network sessions alive, 0 = allow them to drop).",
		normal: "1",
		server: "1",
	},
	standby: {
		description:
			"Transition from sleep to lower-power standby (1 = enabled, 0 = stay in regular sleep).",
		normal: "1",
		server: "0",
	},
	ttyskeepawake: {
		description:
			"Prevent sleep while remote tty sessions are active (1 = stay awake for SSH/tty sessions, 0 = sleep anyway).",
		normal: "1",
		server: "1",
	},
	hibernatemode: {
		description:
			"Hibernate mode (0 = RAM only, 3 = safe sleep image plus RAM, 25 = disk hibernation).",
		normal: "3",
		server: "3",
	},
	lessbright: {
		description: "Slightly dim display on battery (1 = enabled, 0 = disabled).",
		normal: "1",
		server: "1",
	},
	powermode: {
		description:
			"CPU power profile (0 = lower power, 1 = balanced, 2 = higher performance).",
		normal: "2",
		server: "2",
	},
	lowpowermode: {
		description: "Low power mode (1 = enabled, 0 = disabled).",
		normal: "0",
		server: "0",
	},
} satisfies Record<string, ModeSetting>;

const RESTART_SETTINGS = {
	restartPowerFailure: {
		command: "-setrestartpowerfailure",
		description:
			"Auto restart after power failure (on = restart when power returns, off = stay off).",
		normal: "off",
		server: "on",
	},
	restartFreeze: {
		command: "-setrestartfreeze",
		description:
			"Auto restart after system freeze (on = restart automatically, off = remain frozen).",
		normal: "off",
		server: "on",
	},
} satisfies Record<string, ModeSetting & { command: string }>;

function isMode(value: string | undefined): value is Mode {
	return value === "normal" || value === "server";
}

function run(command: string, args: readonly string[]) {
	const result = spawnSync(command, args, { stdio: "inherit" });

	if (result.error) {
		console.error(result.error.message);
		process.exit(1);
	}

	if (result.status !== 0) {
		process.exit(result.status ?? 1);
	}
}

function getPmsetArgs(mode: Mode): string[] {
	const args = ["-a"];

	for (const [setting, config] of Object.entries(PMSET_SETTINGS)) {
		args.push(setting, config[mode]);
	}

	return args;
}

const mode = process.argv[2];

if (!isMode(mode)) {
	console.error(
		"Usage: node scripts/mac/install/mac-power-mode.ts <normal|server>",
	);
	process.exit(1);
}

run("sudo", ["pmset", ...getPmsetArgs(mode)]);

for (const config of Object.values(RESTART_SETTINGS)) {
	run("sudo", ["systemsetup", config.command, config[mode]]);
}
