#!/usr/bin/env bash
# version-stamp.sh — a seat says exactly which build it runs (2026-09-22).
#
# The one truth: the repo `main` + the package tag. Dev seats run source;
# the npm package is the container-era artifact — a seat must be able to name
# its build without guessing.
#
# Usage:   version-stamp.sh          -> ymir-<git describe>[@<pkg>]
#          version-stamp.sh --json  -> {"ymir":"<describe>","pkg":"<pkg>|none","root":"<repo>"}
# Env:     BROKK_ROOT_OVERRIDE      the repo root (default: this script's parent)
set -u

ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
describe="unknown"
if [ -d "$ROOT/.git" ] && command -v git >/dev/null 2>&1; then
  describe="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null)" || describe="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi
pkg="none"
[ -f "$ROOT/package.json" ] && pkg="$(node -e "console.log(require('$ROOT/package.json').version || '0')" 2>/dev/null || echo 0)"

case "${1-}" in
  --json) printf '{"ymir":"%s","pkg":"%s","root":"%s"}\n' "$describe" "$pkg" "$ROOT" ;;
  -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) printf 'ymir-%s[@%s]\n' "$describe" "$pkg" ;;
esac