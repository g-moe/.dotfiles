#!/usr/bin/env bash

# Raycast extension runner
# ------------------------
# This script gives the repository one way to run the same command across every
# Raycast extension under packages/raycast/.
#
# Flow:
# 1. Find each direct child directory that contains a package.json.
# 2. For "install", install every extension from its own package-lock.json.
# 3. For package scripts such as "test", "typecheck", and "build", run
#    them one extension at a time and stop immediately if one fails.
# 4. For "dev", start every extension watcher at the same time. When this
#    script is stopped, or any watcher exits, stop the remaining watchers too.
#
# Root package.json commands call this file, so adding another directory under
# packages/raycast/ automatically includes that extension.

# Fail on errors, missing variables, and failed commands inside pipelines.
set -euo pipefail
# An empty package search should produce an empty list instead of a literal "*".
shopt -s nullglob

usage() {
	echo "Usage: npm run raycast <command>"
	echo
	echo "Commands:"
	echo "  install       Install every extension from its lockfile"
	echo "  dev           Start every extension in development mode"
	echo "  build         Build every extension"
	echo "  test          Test every extension"
	echo "  typecheck     Typecheck every extension"
	echo "  format-check  Format-check every extension"
	echo "  check         Test, typecheck, build, and format-check everything"
}

if (($# != 1)); then
	usage
	exit 2
fi

case "$1" in
install) command="ci" ;;
dev | build | test | typecheck | format-check | check) command="$1" ;;
*)
	usage
	exit 2
	;;
esac

# Each matching manifest represents one Raycast extension.
package_files=(packages/raycast/*/package.json)
if ((${#package_files[@]} == 0)); then
	echo "No Raycast extensions found." >&2
	exit 1
fi

# Run the requested operation inside one extension directory.
run() {
	local package_dir="${1%/package.json}"
	local operation="$2"
	if [[ "$operation" == "ci" ]]; then
		npm --prefix "$package_dir" ci
	else
		npm --prefix "$package_dir" run "$operation"
	fi
}

run_all() {
	local operation="$1"
	for package_file in "${package_files[@]}"; do
		run "$package_file" "$operation"
	done
}

if [[ "$command" == "format-check" ]]; then
	oxfmt --check packages/raycast
	exit
fi

if [[ "$command" == "check" ]]; then
	run_all test
	run_all typecheck
	run_all build
	oxfmt --check packages/raycast
	exit
fi

# Finite commands run in order so failures are clear and stop the whole run.
if [[ "$command" != "dev" ]]; then
	run_all "$command"
	exit
fi

# Development watchers are long-running, so launch them together and remember
# their process IDs for cleanup.
pids=()
cleanup() {
	for pid in "${pids[@]}"; do
		kill "$pid" 2>/dev/null || true
	done
}
trap cleanup EXIT INT TERM

for package_file in "${package_files[@]}"; do
	run "$package_file" dev &
	pids+=("$!")
done

# Keep supervising the watchers. If one ends, return its result and let the
# cleanup trap stop every watcher that is still running.
while true; do
	for pid in "${pids[@]}"; do
		if ! kill -0 "$pid" 2>/dev/null; then
			wait "$pid"
			exit $?
		fi
	done
	sleep 1
done
