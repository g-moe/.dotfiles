#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

readonly AUDIO_PLAYER_ID='com.apple.QuickTimePlayerX'
readonly AUDIO_TYPE_IDS=(
  public.mp3
  com.apple.m4a-audio
  com.microsoft.waveform-audio
  public.aiff-audio
  public.aifc-audio
  org.xiph.flac
)

configure_default_applications() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  load_homebrew || die 'Homebrew is not installed.'
  mac_browser
  mac_audio
}

mac_browser() {
  local attempt

  if [[ "$(duti -d http 2>/dev/null || true)" == 'com.google.Chrome' &&
    "$(duti -d https 2>/dev/null || true)" == 'com.google.Chrome' ]]; then
    return 0
  fi
  ask_binary 'Make Chrome the default browser?' || return 0

  # macOS asks the signed-in user to approve a default-browser change. Setting
  # the HTTP handler opens that one system prompt and approval covers HTTPS too.
  silent duti -s com.google.Chrome http || true
  log 'Approve Chrome in the macOS default-browser prompt.'
  for attempt in {1..120}; do
    if [[ "$(duti -d http 2>/dev/null || true)" == 'com.google.Chrome' &&
      "$(duti -d https 2>/dev/null || true)" == 'com.google.Chrome' ]]; then
      return 0
    fi
    sleep 1
  done

  die 'Chrome was not approved as the default browser.'
}

# Music adds every file it opens to the library, so audio must open in QuickTime Player instead.
# duti cannot replace Music for most audio types, so this sets them through NSWorkspace.
mac_audio() {
  local type_id
  local unset_type_ids=()

  for type_id in "${AUDIO_TYPE_IDS[@]}"; do
    [[ "$(duti -d "$type_id" 2>/dev/null || true)" == "$AUDIO_PLAYER_ID" ]] ||
      unset_type_ids+=("$type_id")
  done
  ((${#unset_type_ids[@]} > 0)) || return 0

  has xcrun || die 'xcrun is required. Run npm run install:development first.'
  xcrun swift -e '
    import AppKit
    import Darwin
    import UniformTypeIdentifiers

    let workspace = NSWorkspace.shared
    let playerId = CommandLine.arguments[1]
    let typeIds = CommandLine.arguments.dropFirst(2)
    guard let application = workspace.urlForApplication(withBundleIdentifier: playerId) else {
      FileHandle.standardError.write(Data("\(playerId) is not installed.\n".utf8))
      exit(EXIT_FAILURE)
    }

    for typeId in typeIds {
      guard let type = UTType(typeId) else {
        FileHandle.standardError.write(Data("macOS does not know the type \(typeId).\n".utf8))
        exit(EXIT_FAILURE)
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
        FileHandle.standardError.write(Data("Could not set the default app for \(typeId): \(failure)\n".utf8))
        exit(EXIT_FAILURE)
      }
      guard workspace.urlForApplication(toOpen: type) == application else {
        FileHandle.standardError.write(Data("macOS did not keep the default app for \(typeId).\n".utf8))
        exit(EXIT_FAILURE)
      }
    }
  ' "$AUDIO_PLAYER_ID" "${unset_type_ids[@]}" || die 'Could not make QuickTime Player the default audio player.'
}

linux() {
  local browser

  case "$LINUX_ARCH" in
    amd64) browser='google-chrome.desktop' ;;
    arm64) browser='brave-browser.desktop' ;;
    *) die "No default browser is configured for $LINUX_ARCH" ;;
  esac

  [[ "$(xdg-settings get default-web-browser 2>/dev/null || true)" == "$browser" ]] && return 0
  ask_binary "Make ${browser%.desktop} the default browser?" || return 0
  xdg-settings set default-web-browser "$browser"

  [[ "$(xdg-settings get default-web-browser)" == "$browser" ]] ||
    die 'The default browser was not saved.'
}

configure_default_applications "$1"
