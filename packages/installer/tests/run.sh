#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tests=(
  "$TESTS_DIR/install.sh"
  "$TESTS_DIR/setup/structure.sh"
  "$TESTS_DIR/setup/access/checks.sh"
  "$TESTS_DIR/setup/appearance/checks.sh"
  "$TESTS_DIR/setup/apps/checks.sh"
  "$TESTS_DIR/setup/desktop/checks.sh"
  "$TESTS_DIR/setup/development/checks.sh"
  "$TESTS_DIR/setup/files/checks.sh"
  "$TESTS_DIR/setup/input/checks.sh"
  "$TESTS_DIR/setup/system/checks.sh"
  "$TESTS_DIR/lib/lib-install.sh"
  "$TESTS_DIR/lib/lib-packages.sh"
  "$TESTS_DIR/lib/retire.sh"
  "$TESTS_DIR/repository/dotfiles-layout.sh"
)

for test_file in "${tests[@]}"; do
  bash "$test_file"
done

printf 'All installer tests passed.\n'
