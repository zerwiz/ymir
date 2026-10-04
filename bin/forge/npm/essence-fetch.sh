#!/usr/bin/env bash
# essence-fetch.sh — the npm world's self-heal: npm's packer refuses dotfolders
# (the .agents/RULES law), so when this tree lacks them, fetch them from the
# public repo — the architecture materializes regardless of install road.
set -u
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MISSING=0
[ -d "$ROOT/.agents/skills" ] || MISSING=1
[ -d "$ROOT/RULES" ] || MISSING=1
if [ "$MISSING" = 0 ]; then echo "essence: .agents/RULES present"; exit 0; fi
tmp="$(mktemp -d)"
echo "essence: fetching .agents + RULES from the repo …" >&2
git clone --depth 1 -q https://github.com/zerwiz/ymir "$tmp/ymir" 2>/dev/null || { echo "essence: fetch failed (offline?) — the dotfolders stay absent" >&2; rm -rf "$tmp"; exit 1; }
mkdir -p "$ROOT"
cp -r "$tmp/ymir/.agents" "$ROOT/.agents" 2>/dev/null
cp -r "$tmp/ymir/RULES" "$ROOT/RULES" 2>/dev/null
rm -rf "$tmp"
[ -d "$ROOT/.agents/skills" ] && [ -d "$ROOT/RULES" ] && echo "essence: .agents/RULES seated" || echo "essence: partial — check the fetch"