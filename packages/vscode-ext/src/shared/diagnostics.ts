import type {
	BetterErrorPosition,
	BetterErrorRange,
	BetterErrorSeverity,
} from "./contracts/betterErrors";

type EditorRange = {
	start: BetterErrorPosition;
	end: BetterErrorPosition;
};

export function toBetterErrorRange(range: EditorRange): BetterErrorRange {
	return {
		start: toBetterErrorPosition(range.start),
		end: toBetterErrorPosition(range.end),
	};
}

export function formatDiagnosticSeverity(
	severity: number,
): BetterErrorSeverity {
	switch (severity) {
		case 0:
			return "error";
		case 1:
			return "warning";
		case 2:
			return "information";
		case 3:
			return "hint";
		default:
			return "unknown";
	}
}

function toBetterErrorPosition(
	position: BetterErrorPosition,
): BetterErrorPosition {
	return {
		line: position.line,
		character: position.character,
	};
}
