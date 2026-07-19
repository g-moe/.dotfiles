#!/usr/bin/env bash

# Check the exact package retirement shapes before any uninstall runs.
# Usage: validate_retire_file packages/retire.json
validate_retire_file() {
  local file="$1"

  jq -e '
    type == "array" and
    length == (unique | length) and
    all(.[];
      (.name | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9+._:@/-]*$")) and
      (if .platform == "mac" then
        .manager == "brew" and
        (.type == "formula" or .type == "cask") and
        (keys | sort) == ["manager", "name", "platform", "type"]
      elif .platform == "linux" then
        .manager == "apt" and
        (keys | sort) == ["manager", "name", "platform"]
      else false end)
    )
  ' "$file" >/dev/null || die "Invalid package retirement file: $file"
}
