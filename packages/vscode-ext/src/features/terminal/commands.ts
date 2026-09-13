import { TERMINAL_STATE_KEY } from "./constants";

export const TERMINAL_COMMANDS = {
	focus: `${TERMINAL_STATE_KEY}.focus`,
	focusAndMaximize: `${TERMINAL_STATE_KEY}.focusAndMaximize`,
} as const;
