#!/usr/bin/env bash
# install.sh — build THIS release in place (the app contract, Ymir plan 01 §3).
#
# Ymir's `bin/apps/apps.sh` exports a commit into $YMIR_APPS_HOME/<app>/releases/<sha>/,
# runs this script there, then runs `install.sh --check` and flips `current` only on
# green. Run it by hand the same way from a checkout to build it where it stands.
#
#   install.sh          deps from the lock file, the build, the Electron runtime,
#                       the launcher and units rendered from this repo's templates
#   install.sh --check  change NOTHING; exit 1 naming what is not right
#
# The environment apps.sh hands over (each has a default, so the script runs alone too):
#   YMIR_APP_RELEASE     this folder            YMIR_APP_STATE_DIR   never in a release
#   YMIR_APP_CONFIG_DIR  never in a release      YMIR_RUNTIME_DIR     Ymir's pin, when present
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$(sed -n 's/^name:[[:space:]]*//p' "$HERE/app.yaml" | head -1)"
STATE="${YMIR_APP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/$APP}"
CONFIG="${YMIR_APP_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/$APP}"

case "$HERE" in
  */ymir-runtime/apps/*|*/ymir/apps/*)
    printf 'error: refusing to build inside a Ymir tree (%s) — an installed app has its own home\n' "$HERE" >&2
    exit 1 ;;
esac

check() {
  local bad=0
  # 1. the build exists (fault 1's guard: a page that answers HTML where JSON is owed is
  #    caught by the app's own smoke, which this calls when it has one)
  # 2. the window class is the declared one (fault 5)
  # 3. every icon a launcher names resolves (fault 3)
  # Each app fills these in; an empty check is a red check.
  printf 'error: this app has not written its --check yet\n' >&2
  bad=1
  return "$bad"
}

if [ "${1-}" = --check ]; then check; exit $?; fi

mkdir -p "$STATE" "$CONFIG"
# deps, build, Electron runtime, launcher, units — each app writes its own here.
printf 'error: this app has not written its install yet\n' >&2
exit 1
