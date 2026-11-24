#!/usr/bin/env bash
# ymir-release.sh — `ymir release`: npm is the T2 door (plan 365); every other verb is the release engine.
#   ymir release npm <x.y.z> [--yes]     the npm runbook as one door (a dry run unless --yes)
#   ymir release build|flip|status|rollback|…   bin/engine/release.sh
HERE="$(CDPATH='' command cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1-}" in
  npm) shift; exec bash "$HERE/../forge/npm/release-npm.sh" "$@" ;;
  *)   exec bash "$HERE/release.sh" "$@" ;;
esac
