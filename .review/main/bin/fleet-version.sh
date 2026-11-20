#!/usr/bin/env bash
# fleet-version.sh — is the fleet on ONE version? (plan 51, Phase 2)
#
# The fleet is versioned together (law 5). This reports the three versions that
# drifted apart on 2026-09-23 — the tree, the npm install, and the published
# latest — and judges them, so a body on a different version can no longer go
# unnoticed. Offline-safe: an unreachable npm registry is reported, never a crash.
#
#   fleet-version.sh            # this machine + the published line, as TOON
#   fleet-version.sh --json
#   fleet-version.sh check      # exit 1 on drift; 0 when they agree
#   fleet-version.sh --version
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MODE=toon
case "${1-}" in --json) MODE=json ;; check) MODE=check ;; esac

# the tree's declared version
TREE="$(node -p "require('$ROOT/package.json').version" 2>/dev/null || echo "")"

# the installed @zerwiz/ymir, wherever npm keeps its global root
INSTALLED=""
if command -v npm >/dev/null 2>&1; then
  _g="$(npm root -g 2>/dev/null)"
  [ -n "$_g" ] && INSTALLED="$(node -p "try{require('$_g/@zerwiz/ymir/package.json').version}catch(e){''}" 2>/dev/null || echo "")"
fi

# the published latest — network-optional
PUBLISHED=""
if command -v npm >/dev/null 2>&1; then
  PUBLISHED="$(npm view @zerwiz/ymir version 2>/dev/null || true)"
fi
[ -n "$PUBLISHED" ] || PUBLISHED="unreachable"

# verdict — semver-ish via sort -V
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }
VERDICT="in sync"; VERDICT_NOTE="tree, install, and publish agree"
if [ -z "$TREE" ]; then
  VERDICT="unknown"; VERDICT_NOTE="no package.json at $ROOT"
elif [ -n "$INSTALLED" ] && [ "$INSTALLED" != "$TREE" ]; then
  VERDICT="drift"; VERDICT_NOTE="tree $TREE != installed $INSTALLED — reconcile before publish"
elif [ "$PUBLISHED" != "unreachable" ] && newer "$TREE" "$PUBLISHED"; then
  VERDICT="ahead"; VERDICT_NOTE="tree $TREE is ahead of published $PUBLISHED — ready to publish"
elif [ "$PUBLISHED" != "unreachable" ] && newer "$PUBLISHED" "$TREE"; then
  VERDICT="behind"; VERDICT_NOTE="tree $TREE is behind published $PUBLISHED — pull the line forward"
fi

if [ "$MODE" = json ]; then
  python3 - "$TREE" "$INSTALLED" "$PUBLISHED" "$VERDICT" "$VERDICT_NOTE" <<'PY'
import json, sys
tree, installed, published, verdict, note = sys.argv[1:6]
print(json.dumps({"tree": tree or None, "installed": installed or None,
                  "published": published, "verdict": verdict, "note": note}))
PY
  exit 0
fi

printf 'fleet_version[4]{scope,version,note}:\n'
printf '  "tree","%s","package.json in this repo"\n' "${TREE:-none}"
printf '  "installed","%s","@zerwiz/ymir in the global prefix"\n' "${INSTALLED:-none}"
printf '  "published","%s","npm latest"\n' "$PUBLISHED"
printf '  "verdict","%s","%s"\n' "$VERDICT" "$VERDICT_NOTE"

if [ "$MODE" = check ] && [ "$VERDICT" = "drift" ]; then exit 1; fi
exit 0
