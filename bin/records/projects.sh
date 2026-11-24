#!/usr/bin/env bash
# projects.sh — `ymir projects`: see, add and tend every project you work on (plan 367).
#
#   projects.sh [list] [flags]               # every project with a clone on some seat (flags: projects-status.sh --help)
#   projects.sh add <repo-url|path> [--id ID] [--realm R] [--kit [--report]] [--no-clone]
#                                            # register it, clone it where this seat keeps clones, optionally seat the kit
#   projects.sh kit update <id> [--report]   # refresh the collaboration kit in that project's clone
#   projects.sh reap <id> [--apply]          # stale worktrees: branch merged or path gone. Dry run unless --apply
#
# The disk law: a clone is refused with less than PROJECTS_MIN_FREE_GB (40) free. Reap removes only worktrees whose
# branch is merged, that are clean and unclaimed — never the primary checkout, never the one you stand in, never a
# branch with unmerged work (git branch -d, not -D).
# Env: YMIR_HOME · YMIR_PROJECTS_DIR (where clones land; default ~/CodeP) · PROJECTS_MIN_FREE_GB
# Exit: 0 ok · 1 refused (the reason is named) · 2 usage
set -uo pipefail
ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")"
STATUS="$ROOT/bin/records/projects_status.py"
usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf 'help: %s\n' "$2" >&2; exit "${3:-1}"; }
HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"
REG="$HOME_DIR/hodd/identity/projects.yaml"

resolve() {  # <id> -> prints the clone path on this seat
  python3 - "$STATUS" "$1" <<'PY'
import sys, importlib.util
spec = importlib.util.spec_from_file_location("ps", sys.argv[1]); ps = importlib.util.module_from_spec(spec); spec.loader.exec_module(ps)
for p in ps.registry():
    if str(p.get("id")) == sys.argv[2]:
        c = ps.clone_here(p, ps.this_seat())
        print(c); sys.exit(0 if c else 1)
sys.exit(2)
PY
}

cmd="${1:-list}"; [ $# -gt 0 ] && shift
case "$cmd" in
  -h|--help|help) usage; exit 0 ;;
  list|status) exec python3 "$STATUS" "$@" ;;
  add)
    src=""; id=""; realm="work"; kit=0; report=0; noclone=0
    while [ $# -gt 0 ]; do case "$1" in
      --id) id="$2"; shift 2 ;; --realm) realm="$2"; shift 2 ;; --kit) kit=1; shift ;;
      --report) report=1; kit=1; shift ;; --no-clone) noclone=1; shift ;;
      -*) die "unknown flag $1" "projects.sh --help" 2 ;; *) src="$1"; shift ;; esac; done
    [ -n "$src" ] || die "add needs a repo URL or a path" "projects.sh add https://github.com/owner/repo" 2
    min="${PROJECTS_MIN_FREE_GB:-40}"
    if [ -e "$src/.git" ]; then
      clone="$(realpath "$src")"; url="$(git -C "$clone" remote get-url origin 2>/dev/null || true)"
    else
      url="$src"; base="$(basename "${src%.git}")"
      dest="${YMIR_PROJECTS_DIR:-$HOME/CodeP}/$base"; clone="$dest"
      if [ "$noclone" = 0 ]; then
        [ -e "$dest" ] && die "$dest already exists" "pass the path instead: projects.sh add $dest"
        mkdir -p "$(dirname "$dest")"
        free=$(df -BG --output=avail "$(dirname "$dest")" | tail -1 | tr -dc 0-9)
        [ "${free:-0}" -ge "$min" ] || die "only ${free:-0} GB free; the disk law keeps $min GB" "free space, then run it again"
        if command -v gh >/dev/null 2>&1 && printf '%s' "$url" | grep -q 'github.com'; then
          gh repo clone "$url" "$dest" >/dev/null 2>&1 || git clone -q "$url" "$dest" || die "clone failed: $url"
        else git clone -q "$url" "$dest" || die "clone failed: $url"; fi
      fi
    fi
    [ -d "$clone" ] || die "no clone at $clone"
    owner=""; repo="$(basename "${url%.git}")"
    case "$url" in *github.com[:/]*) t="${url##*github.com[:/]}"; t="${t%.git}"; owner="${t%%/*}"; repo="${t#*/}" ;; esac
    [ -n "$id" ] || id="$(printf '%s' "$repo" | tr 'A-Z_' 'a-z-')"
    seat="${YMIR_SEAT:-$(hostname -s)}"
    mkdir -p "$(dirname "$REG")"
    python3 - "$REG" "$id" "$repo" "$realm" "$clone" "$seat" "$owner" <<'PY' || exit $?
import os, sys
reg, pid, repo, realm, clone, seat, owner = sys.argv[1:8]
text = open(reg).read() if os.path.isfile(reg) else ""
if f"- id: {pid}\n" in text or (owner and f"    repo: {repo}\n" in text and f"    owner: {owner}\n" in text):
    sys.stderr.write(f"error: {pid} is already registered\nhelp: the registry is append-only; edit the row by hand\n"); sys.exit(1)
row = f"- id: {pid}\n  name: {repo}\n  realm: {realm}\n  repo: {clone}\n  clones:\n    {seat}: {clone}\n"
if owner:
    row += f"  git:\n    host: github.com\n    owner: {owner}\n    repo: {repo}\n    remote: origin\n    default_branch: main\n    auth: gh\n"
if not text.strip():
    text = "projects:\n"
elif not text.endswith("\n"):
    text += "\n"
open(reg, "w").write(text + row)
PY
    printf 'added %s (%s) — clone %s\n' "$id" "$realm" "$clone"
    if [ "$kit" = 1 ]; then
      flags=(); [ "$report" = 1 ] && flags+=(--report)
      bash "$ROOT/bin/collab/standardise.sh" --apply "$clone" "${flags[@]}" | tail -2
    fi
    if [ -d "$HOME_DIR/.git" ] && [ -x "$ROOT/bin/vault/home-sync.sh" ]; then
      bash "$ROOT/bin/vault/home-sync.sh" ship "projects: register $id" hodd/identity/projects.yaml >/dev/null 2>&1 \
        && echo "home: shipped" || echo "home: not shipped — run bin/vault/home-sync.sh ship \"projects: register $id\" hodd/identity/projects.yaml"
    else echo "home: not a git repo here — registry written, nothing to ship"; fi
    ;;
  kit)
    [ "${1:-}" = update ] || die "usage: projects.sh kit update <id> [--report]" "" 2
    shift; id="${1:-}"; shift || true
    [ -n "$id" ] || die "kit update needs a project id" "projects.sh list" 2
    clone="$(resolve "$id")" || die "no clone of $id on this seat" "projects.sh add <url>"
    bash "$ROOT/bin/collab/standardise.sh" --apply "$clone" "$@" | tail -3 ;;
  reap)
    id="${1:-}"; shift || true; apply=0; [ "${1:-}" = --apply ] && apply=1
    [ -n "$id" ] || die "reap needs a project id" "projects.sh reap <id> [--apply]" 2
    clone="$(resolve "$id")" || die "no clone of $id on this seat"
    here="$(pwd -P)"; n=0
    while IFS=$'\t' read -r path branch reason claimed; do
      [ "$claimed" = True ] && { echo "keep  $path — claimed"; continue; }
      case "$here/" in "$path"/*) echo "keep  $path — you stand in it"; continue ;; esac
      if [ "$reason" = "branch merged" ] && [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
        echo "keep  $path — has uncommitted work"; continue; fi
      n=$((n+1))
      if [ "$apply" = 1 ]; then
        if [ "$reason" = "path gone" ]; then git -C "$clone" worktree prune && echo "pruned $path"
        else git -C "$clone" worktree remove "$path" && git -C "$clone" branch -d "$branch" >/dev/null 2>&1; echo "reaped $path ($branch)"; fi
      else echo "would reap $path — $reason"; fi
    done < <(python3 "$STATUS" --json --local --no-net | python3 -c '
import json,sys
for r in json.load(sys.stdin)["projects"]:
    if r["id"]==sys.argv[1]:
        for w in r["where"][:1]:
            for t in w["worktrees"]:
                if t["stale"]: print("\t".join([t["path"],t["branch"],t["reason"],str(t["claimed"])]))
        break' "$id")
    [ "$apply" = 1 ] || echo "dry run — $n stale; add --apply to remove"
    ;;
  *) die "unknown action $cmd" "projects.sh --help" 2 ;;
esac
