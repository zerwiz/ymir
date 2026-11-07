#!/usr/bin/env bash
# mjollnir.sh — the hammer (W0018). An issue becomes a PR: read the issue, cut a
# Yggdrasil worktree, spawn an Eindri (Utgard-sealed), run tests, open a PR, and
# hand it to Glitnir for human review. Never force-merges. Galdr-style TOON.
#
# Usage:
#   mjollnir.sh run --repo <dir> --issue <n> [--mode direct-PR|no-mistakes|local-only]
#                  [--harness <h>] [--isolation auto|on|off] [--no-spawn]
#   mjollnir.sh run --project <id> --issue <n>   (the repo resolved from the registry)
#   mjollnir.sh intake [--repo <id>]... [--ttl <s>] [--limit <n>] [--cache-only] [--json]
#   mjollnir.sh clone <id> [--dir <path>] [--from <url>]
#   mjollnir.sh status
#   mjollnir.sh --version
set -u

VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$_yr/../vault/hoard-lib.sh" "$_yr/../../vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
HOME_DIR=""
declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR 2>/dev/null
[ -n "$HOME_DIR" ] || HOME_DIR="${YMIR_HOME:-}"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
ENV_FILE="${BROKK_ENV_FILE:-$YMIR_ENV_FILE}"

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }
CMD="${1-}"; shift || true
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac

# intake — the hammer's EYE, before its blow (plan 210 P1).
# WHY: measured 2026-11-06, the only issue reader in the whole tree was line 79 of this
# script — one issue, one repo, already named by whoever spawned it. The registry held 78
# projects and nothing read them, so "add the user's repos" could not start. `intake` reads
# every registered repo once (issues, PRs, base health, alerts), caches it under the home,
# and reports a source it could not read WITH ITS REASON — never a zero that means "I did
# not look". It writes nothing to GitHub, and it never touches a working tree.
if [ "$CMD" = intake ]; then
  [ -x "$SCRIPT_DIR/intake.py" ] || [ -f "$SCRIPT_DIR/intake.py" ] || {
    printf 'error: the intake engine is missing\nhelp: bin/forge/intake.py (plan 210 P1)\n' >&2; exit 1; }
  command -v python3 >/dev/null 2>&1 || { printf 'error: python3 is required\n' >&2; exit 1; }
  HOME_DIR=""
  declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR 2>/dev/null
  [ -n "$HOME_DIR" ] || HOME_DIR="${YMIR_HOME:-}"
  [ -n "$HOME_DIR" ] || { printf 'error: the home is unresolved\nhelp: bin/vault/hoard-lib.sh names it\n' >&2; exit 1; }
  exec python3 "$SCRIPT_DIR/intake.py" --home "$HOME_DIR" "$@"
fi

# clone — a FAR repo becomes a workable one (plan 210 P3).
# WHY: `intake` reads any registered repo without a tree, but a FIX needs one, and the first
# measurement found 67 of 78 rows with no clone at all. The door writes to exactly the path
# `project-git.sh --field clone` prints — one resolver, so the diagnosis and the door cannot
# disagree — and it refuses three things it must never do: clone over an existing tree, clone
# into the public code tree (Rule 04: the tree ships, a workspace does not), and clone a row
# that cannot name a remote (a guess about which repo a row means is worse than a refusal).
if [ "$CMD" = clone ]; then
  CID="${1-}"; shift || true
  CDIR=""; CFROM=""
  while [ $# -gt 0 ]; do case "$1" in
    --dir) CDIR=${2-}; shift 2 ;; --from) CFROM=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/forge/mjollnir.sh clone <id> [--dir <path>] [--from <url>]\n' "$1" >&2; exit 2 ;;
  esac; done
  [ -n "$CID" ] || { printf 'error: clone needs a project id\nhelp: bin/agents/project-git.sh list\n' >&2; exit 2; }
  PG="$SCRIPT_DIR/../agents/project-git.sh"
  [ -r "$PG" ] || { printf 'error: the registry door is missing: %s\n' "$PG" >&2; exit 1; }
  C_OWNER="$(bash "$PG" "$CID" --field owner 2>/dev/null || true)"
  C_NAME="$(bash "$PG" "$CID" --field repo 2>/dev/null || true)"
  C_BRANCH="$(bash "$PG" "$CID" --field default_branch 2>/dev/null || true)"
  C_HOST="$(bash "$PG" "$CID" --field host 2>/dev/null || true)"
  DEST="${CDIR:-$(bash "$PG" "$CID" --field clone 2>/dev/null || true)}"
  [ -n "$DEST" ] || { printf 'error: %s cannot name a remote\nhelp: bin/agents/project-git.sh doctor names the row — a git{} block is what a clone needs\n' "$CID" >&2; exit 1; }
  case "$DEST" in
    "$ROOT"/*) printf 'error: %s resolves inside the public tree (%s)\nhelp: a hall lives under the private home — the tree ships, a workspace does not (Rule 04)\n' "$CID" "$DEST" >&2; exit 1 ;;
  esac
  [ -e "$DEST" ] && { printf 'error: %s already exists at %s\nhelp: use it (it is already a hall) or name another --dir\n' "$CID" "$DEST" >&2; exit 1; }
  URL="${CFROM:-https://${C_HOST:-github.com}/$C_OWNER/$C_NAME.git}"
  mkdir -p "$(dirname "$DEST")"
  err="$(mktemp)"
  if ! git clone --quiet ${C_BRANCH:+--branch "$C_BRANCH"} "$URL" "$DEST" 2>"$err"; then
    why="$(tail -1 "$err" 2>/dev/null | cut -c1-200)"; rm -f "$err"
    printf 'error: clone failed — %s\nhelp: the remote is %s (a private repo needs gh auth: bin/vault/hodd.sh emit secrets/platform.env)\n' "${why:-git refused}" "$URL" >&2
    rmdir "$DEST" 2>/dev/null || true
    exit 1
  fi
  rm -f "$err"
  printf 'hall[1]{project,path,branch,remote}:\n  "%s","%s","%s","%s"\n' \
    "$CID" "$DEST" "$(git -C "$DEST" branch --show-current 2>/dev/null)" "$URL"
  exit 0
fi

REPO=""; ISSUE=""; MODE=direct-PR; HARNESS=""; ISO=auto; NOSPAWN=0; TITLE=""; BODY=""; PROJECT=""
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
    --project) PROJECT=${2-}; shift 2 ;;
    *) shift ;;
  esac
done

if [ "$CMD" = status ]; then
  printf 'mjollnir[2]{field,value}:\n'
  printf '  "repo","%s"\n' "${REPO:-$ROOT}"
  printf '  "pending","%s"\n' "$(find "$YMIR_DATA_DIR" -maxdepth 2 -name 'brief.md' -path '*issue-*' 2>/dev/null | wc -l | tr -d ' ')"
  exit 0
fi
[ "$CMD" = run ] || { printf 'error: unknown command %s\nhelp: bin/forge/mjollnir.sh [run|intake|status|--version]\n' "$CMD" >&2; exit 2; }
[ -n "$ISSUE" ] || { printf 'error: run needs --issue <n>\n' >&2; exit 2; }

# The `no-mistakes` posture runs through the OSS clean-PR gate engine.
if [ "$MODE" = "no-mistakes" ]; then
  command -v no-mistakes >/dev/null 2>&1 || { printf 'error: no-mistakes engine not installed\nhelp: bin/engine/ymir-install.sh (github.com/kunchenguid/no-mistakes)\n' >&2; exit 1; }
  [ -f "$ROOT/.no-mistakes.yaml" ] || printf 'warn: .no-mistakes.yaml absent — the gate uses defaults\n' >&2
fi
# --project <id> — the registry names the tree, so a far repo is never remembered by path
# (plan 210 P0/P5). An id with no clone is REFUSED with the road to take, never guessed:
# this is the honest half of "the user can add all his repos".
if [ -n "$PROJECT" ] && [ -z "$REPO" ]; then
  command -v python3 >/dev/null 2>&1 || { printf 'error: python3 is required to resolve a project id\n' >&2; exit 1; }
  _why=0
  REPO=$(python3 - "$PROJECT" "$HOME_DIR" "$HOME" "$ROOT" <<'PY'
import os, sys
pid, ymir_home, home, root = sys.argv[1:5]
try:
    import yaml
except ImportError:
    sys.exit(1)
reg = os.path.join(ymir_home, "hodd", "identity", "projects.yaml")
try:
    rows = (yaml.safe_load(open(reg, encoding="utf-8")) or {}).get("projects") or []
except OSError:
    sys.exit(1)
row = next((r for r in rows if isinstance(r, dict) and r.get("id") == pid), None)
if not row:
    sys.exit(2)
path = str(row.get("repo") or "").strip()
if os.path.isabs(path):
    cands = [path]
else:
    cands = [os.path.normpath(os.path.join(base, path or ".")) for base in (root, home, ymir_home)]
for cand in cands:
    if os.path.isdir(cand):
        print(cand)
        sys.exit(0)
sys.exit(3)
PY
) || _why=$?
  if [ -z "$REPO" ]; then
    case "$_why" in
      2) printf 'error: no project named %s in the registry\nhelp: bin/agents/project-git.sh list\n' "$PROJECT" >&2 ;;
      3) printf 'error: %s names no local clone\nhelp: it can be READ (bin/forge/mjollnir.sh intake --repo %s) but not fixed until it is cloned\n' "$PROJECT" "$PROJECT" >&2 ;;
      *) printf 'error: could not resolve --project %s (the registry is unreadable)\nhelp: bin/agents/project-git.sh doctor\n' "$PROJECT" >&2 ;;
    esac
    exit 1
  fi
fi
[ -n "$REPO" ] || { printf 'error: run needs --repo <dir> or --project <id>\n' >&2; exit 2; }
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
"$SCRIPT_DIR/../agents/erindi-brief.sh" "$ID" "$(basename "$REPO")" --mode "$MODE" >/dev/null 2>&1 || true
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
