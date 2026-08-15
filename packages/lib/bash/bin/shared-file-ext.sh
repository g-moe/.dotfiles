#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$BIN_DIR/../lib.sh"

extensions=(
  ts tsx js jsx mjs cjs py rs go swift zig c h cpp hpp css scss vue svelte
  json yaml yml toml env ini conf cfg sh zsh bash fish md mdx txt
)

case "$(uname -s)" in
  Darwin)
    has xcrun || die 'xcrun is required. Run npm run install:development first.'
    xcrun --find swift >/dev/null 2>&1 ||
      die 'Swift is required. Run npm run install:development first.'
    xcrun swift -e '
      import AppKit
      import Darwin
      import UniformTypeIdentifiers

      let workspace = NSWorkspace.shared
      guard let application = workspace.urlForApplication(withBundleIdentifier: "com.vscodium") else {
        FileHandle.standardError.write(Data("VSCodium is not installed.\n".utf8))
        exit(EXIT_FAILURE)
      }

      for extensionName in CommandLine.arguments.dropFirst() {
        guard let type = UTType(filenameExtension: extensionName) else {
          FileHandle.standardError.write(Data("macOS could not resolve the UTI for .\(extensionName).\n".utf8))
          exit(EXIT_FAILURE)
        }
        if workspace.urlForApplication(toOpen: type) == application {
          continue
        }

        let done = DispatchSemaphore(value: 0)
        var failure: Error?
        workspace.setDefaultApplication(at: application, toOpen: type) { error in
          failure = error
          done.signal()
        }
        while done.wait(timeout: .now()) != .success {
          RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        if let failure {
          FileHandle.standardError.write(Data("Could not associate .\(extensionName) with VSCodium: \(failure)\n".utf8))
          exit(EXIT_FAILURE)
        }
        guard workspace.urlForApplication(toOpen: type) == application else {
          FileHandle.standardError.write(Data("macOS did not retain the VSCodium association for .\(extensionName).\n".utf8))
          exit(EXIT_FAILURE)
        }
      }
    ' "${extensions[@]}" || die 'Could not set VSCodium file associations.'
    ;;
  Linux)
    has xdg-mime || die 'xdg-mime is required.'
    for extension in "${extensions[@]}"; do
      temporary_file="$(mktemp "${TMPDIR:-/tmp}/vscodium.XXXXXX.$extension")"
      mime_type="$(xdg-mime query filetype "$temporary_file")"
      rm -f "$temporary_file"
      [[ -n "$mime_type" ]] || continue
      silent xdg-mime default codium.desktop "$mime_type" ||
        die "Could not associate .$extension with VSCodium."
    done
    ;;
  *)
    die 'Only macOS and Linux are supported.'
    ;;
esac
