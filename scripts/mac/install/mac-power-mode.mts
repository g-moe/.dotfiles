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
		normal: "1",
		server: "2",
	},
	lowpowermode: {
		description: "Low power mode (1 = enabled, 0 = disabled).",
		normal: "0",
		server: "0",
	},
	autorestart: {
		description:
			"Auto restart after power failure (1 = restart when power returns, 0 = stay off).",
		normal: "0",
		server: "1",
	},
} satisfies Record<string, ModeSetting>;

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

function getCapabilities(): Set<string> {
	const result = spawnSync("pmset", ["-g", "cap"], {
		encoding: "utf8",
	});

	if (result.error) {
		console.error(result.error.message);
		process.exit(1);
	}

	if (result.status !== 0) {
		process.stderr.write(result.stderr);
		process.exit(result.status ?? 1);
	}

	return new Set(result.stdout.split(/\s+/));
}

function getPmsetArgs(mode: Mode, capabilities: ReadonlySet<string>): string[] {
	const args = ["-a"];

	for (const [setting, config] of Object.entries(PMSET_SETTINGS)) {
		let value = config[mode];

		if (setting === "powermode" && value === "2") {
			if (!capabilities.has("highpowermode")) {
				console.warn(
					"High Power Mode is not supported on this Mac; using balanced mode.",
				);
				value = "1";
			}
		}

		if (setting === "lowpowermode" && !capabilities.has("lowpowermode")) {
			continue;
		}

		args.push(setting, value);
	}

	return args;
}

const mode = process.argv[2];

if (!isMode(mode)) {
	console.error(
		"Usage: node scripts/mac/install/mac-power-mode.mts <normal|server>",
	);
	process.exit(1);
}

run("sudo", ["pmset", ...getPmsetArgs(mode, getCapabilities())]);
