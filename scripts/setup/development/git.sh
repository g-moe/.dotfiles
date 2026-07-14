#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_git() {
  confirm 'Set up Git for this user?' || return 0

  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local name email branch

  name="$(git config --global --get user.name || true)"
  email="$(git config --global --get user.email || true)"
  branch="$(git config --global --get init.defaultBranch || true)"
  [[ -n "$name" ]] || name='garrett'
  [[ -n "$email" ]] || email='114707197+g-moe@users.noreply.github.com'
  [[ -n "$branch" ]] || branch='main'

  while true; do
    name="$(read_value 'Git user name' "$name")"
    [[ -n "$name" ]] && break
    log 'A Git user name is required.'
  done
  while true; do
    email="$(read_value 'Git user email' "$email")"
    [[ "$email" == *@* && "$email" != *[[:space:]]* ]] && break
    log 'Enter an email address without spaces.'
  done
  while true; do
    branch="$(read_value 'Default branch' "$branch")"
    git check-ref-format --branch "$branch" >/dev/null 2>&1 && break
    log 'Enter a valid branch name.'
  done

  git config --global user.name "$name"
  git config --global user.email "$email"
  git config --global init.defaultBranch "$branch"
  git config --global push.autoSetupRemote true
  git config --global fetch.prune true
  git config --global pull.ff only
  git config --global merge.conflictStyle zdiff3
  git config --global diff.colorMoved default
  git config --global diff.algorithm histogram
  git lfs install

  if ! has gh; then
    log 'GitHub CLI is not installed; skipped GitHub sign-in.'
    return 0
  fi
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    log 'GitHub is already signed in.'
  elif confirm 'Sign in to GitHub in your browser?'; then
    gh auth login --hostname github.com --web --git-protocol https
  else
    log 'Skipped GitHub sign-in.'
    return 0
  fi

  gh auth setup-git --hostname github.com
  gh auth status --hostname github.com
}

mac() {
  brew_formula git-lfs
  _configure
}

linux() {
  apt_install git-lfs
  _configure
}

configure_git "$1"
