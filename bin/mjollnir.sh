#!/usr/bin/env bash
# mjollnir.sh — the hammer (W0018). An issue becomes a PR: read the issue, cut a
# Yggdrasil worktree, spawn an Eindri (Utgard-sealed), run tests, open a PR, and
# hand it to Glitnir for human review. Never force-merges. Galdr-style TOON.
#
# Usage:
#   mjollnir.sh run --repo <dir> --issue <n> [--mode direct-PR|no-mistakes|local-only]
#                  [--harness <h>] [--isolation auto|on|off] [--no-spawn]
#   mjollnir.sh status
#   mjollnir.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
ENV_FILE="${BROKK_ENV_FILE:-$YMIR_ENV_FILE}"

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; }
CMD="${1-}"; shift || true
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac

REPO=""; ISSUE=""; MODE=direct-PR; HARNESS=""; ISO=auto; NOSPAWN=0; TITLE=""; BODY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO=${2-}; shift 2 ;;
    --issue) ISSUE=${2-}; shift 2 ;;
    --mode) MODE=${2-direct-PR}; shift 2 ;;
    --harness) HARNESS=${2-}; shift 2 ;;
    --isolation) ISO=${2-auto}; shift 2 ;;
    --no-spawn) NOSPAWN=1; shift ;;
    --title) TITLE=${2-}; shift 2 ;;
    --body) BODY=${2-}; shift 2 ;;
    *) shift ;;
  esac
done

if [ "$CMD" = status ]; then
  printf 'mjollnir[2]{field,value}:\n'
  printf '  "repo","%s"\n' "${REPO:-$ROOT}"
  printf '  "pending","%s"\n' "$(find "$YMIR_DATA_DIR" -maxdepth 2 -name 'brief.md' -path '*issue-*' 2>/dev/null | wc -l | tr -d ' ')"
  exit 0
fi
[ "$CMD" = run ] || { printf 'error: unknown command %s\nhelp: bin/mjollnir.sh [run|status|--version]\n' "$CMD" >&2; exit 2; }
[ -n "$ISSUE" ] || { printf 'error: run needs --issue <n>\n' >&2; exit 2; }

# The `no-mistakes` posture runs through the OSS clean-PR gate engine.
if [ "$MODE" = "no-mistakes" ]; then
  command -v no-mistakes >/dev/null 2>&1 || { printf 'error: no-mistakes engine not installed\nhelp: bin/ymir-install.sh (github.com/kunchenguid/no-mistakes)\n' >&2; exit 1; }
  [ -f "$ROOT/.no-mistakes.yaml" ] || printf 'warn: .no-mistakes.yaml absent — the gate uses defaults\n' >&2
fi
[ -n "$REPO" ] || { printf 'error: run needs --repo <dir>\n' >&2; exit 2; }
[ -d "$REPO" ] || { printf 'error: repo not found: %s\n' "$REPO" >&2; exit 1; }

# 1. Read the issue (GitHub) unless title/body were supplied.
if [ -z "$TITLE" ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  json=$(gh issue view "$ISSUE" --json title,body,url -R "$(git -C "$REPO" remote get-url origin 2>/dev/null || echo .)" 2>/dev/null) || json=""
  if [ -n "$json" ]; then
    TITLE=$(printf '%s' "$json" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("title",""))')
    BODY=$(printf '%s' "$json" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("body",""))')
  fi
fi
[ -n "$TITLE" ] || { printf 'error: could not read issue %s (gh unauth? pass --title/--body)\n' "$ISSUE" >&2; exit 1; }

ID="issue-$ISSUE"
printf 'mjollnir[1]{issue,task,mode,repo}:\n  "%s","%s","%s","%s"\n' "$ISSUE" "$ID" "$MODE" "$REPO"

# 2. Scaffold the brief (the worker's contract).
"$SCRIPT_DIR/erindi-brief.sh" "$ID" "$(basename "$REPO")" --mode "$MODE" >/dev/null 2>&1 || true
BRIEF="$YMIR_DATA_DIR/$ID/brief.md"
if [ -f "$BRIEF" ]; then
  { printf '\n\n## Issue #%s — %s\n\n%s\n' "$ISSUE" "$TITLE" "$BODY"; } >>"$BRIEF"
fi

# 3. Spawn the Eindri (or stop for --no-spawn).
if [ "$NOSPAWN" = 1 ]; then
  printf 'spawned[1]{task,status}:\n  "%s","brief-ready (no-spawn)"\n' "$ID"
  exit 0
fi
ARGS=(agent spawn "$ID" "$REPO" --mode "$MODE" --isolation "$ISO")
[ -n "$HARNESS" ] && ARGS+=(--harness "$HARNESS")
"$SCRIPT_DIR/brokk" "${ARGS[@]}"
printf 'help[1]: the worker opens the PR; Glitnir reviews — Mjollnir never force-merges\n'
