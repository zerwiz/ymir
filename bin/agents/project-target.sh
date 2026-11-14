#!/usr/bin/env bash
# project-target.sh — WHERE an errand's project IS on this machine, what its records are, and the
# worktree the worker sits in. ONE resolver, for every door that sends a worker out.
#
# WHY (plan 291 part 3, the Allfather 2026-11-14: *"when we sending workers for diffrent projects
# the need to be send from the project foldeers they are going to work in so they dont do the
# updates in ymirs repo"*): measured the same day, `eindri-start.sh --project
# <a project's clone>` seated the worker in a worktree of YMIR's repository, so an errand for another
# project would have committed into Ymir's tree. A project is resolved to THIS machine's clone, by
# a path, an id or an alias, through the master registry — never by guessing a convention.
#
# Usage:
#   project-target.sh resolve  <path|id|alias>
#       -> row: key<TAB>value — path, id, name, kind (ymir|other|unregistered), how, clone, host
#          exit 1 and name the registry row to fix when the row has no clone on this machine
#   project-target.sh records  <path|id|alias>
#       -> one line per record: place<TAB>key<TAB>where<TAB>duty
#          exit 3 when the row has no `records:` block (the row to add it to is named on stderr)
#   project-target.sh worktree <path|id|alias> <errand-id>
#       -> row: key<TAB>value — worktree, branch, how, created (yes|no)
#          the worktree is made IN THE PROJECT'S OWN REPOSITORY. For this repository's own project
#          nothing is made here (the engine owns Ymir's worktrees) and kind=ymir says so.
#
# CONVENTIONS, declared in the registry and never in this file (Rule 04: a fleet's facts live in
# the home). A row may carry:
#   worktree:
#     command: scripts/worktree.sh new {id}    # optional: the project's own maker, run in the clone
#     path: .yggdrasil/{id}                    # where the worktree lands, relative to the clone
#     branch: agent/{id}                       # the branch it stands on
# With no block the default is `git worktree add -b eindri/<id> <clone>/.yggdrasil/<id>`.
#
# Exit: 0 ok · 1 refused (the reason names the row or the path) · 2 usage · 3 no records block.
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"

# The home is RESOLVED, never guessed (Rule 07): bin/vault/hoard-lib.sh owns where it lives.
if [ -z "${YMIR_HOME:-}" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  YMIR_HOME="$(bash -c '. "$1/bin/vault/hoard-lib.sh" >/dev/null 2>&1; ymir_home_root out; printf %s "$out"' _ "$ROOT" 2>/dev/null || true)"
  export YMIR_HOME
fi

usage() { sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; }

ACTION="${1:-}"; shift || true
case "$ACTION" in
  -h|--help|"") usage; exit 0 ;;
  resolve|records|worktree) ;;
  -v|--version) printf '1.0.0\n'; exit 0 ;;
  *) printf 'error: unknown action %s\nhelp: project-target.sh resolve|records|worktree <path|id|alias> [<errand-id>]\n' "$ACTION" >&2; exit 2 ;;
esac

TOKEN="${1:-}"
[ -n "$TOKEN" ] || { printf 'error: %s needs a project: a path, an id or an alias\n' "$ACTION" >&2; exit 2; }
ID_ARG="${2:-}"; DRY=0
[ "${3:-}" = "--dry-run" ] && DRY=1
[ "${2:-}" = "--dry-run" ] && { DRY=1; ID_ARG=""; }

# ONE reader of the registry: python owns the YAML, this shell owns the git work. The reader prints
# `key<TAB>value` rows so nothing here has to parse YAML a second time.
reg_rows() {  # <token> <mode:row|records|worktree-block>
  python3 - "$SELF" "$TOKEN" "$1" "$ROOT" <<'PY'
import os, socket, sys
import yaml

door_dir, token, mode, tree = sys.argv[1:5]
home = os.environ.get("YMIR_HOME") or ""
if not home:
    sys.stderr.write("error: the home is unresolved\n"
                     "help: export YMIR_HOME, or install bin/vault/hoard-lib.sh\n")
    raise SystemExit(1)
reg = os.path.join(home, "hodd/identity/projects.yaml")
if not os.path.isfile(reg):
    sys.stderr.write(f"error: no project registry at {reg}\n"
                     "help: the master registry is hodd/identity/projects.yaml in the home\n")
    raise SystemExit(1)
projects = (yaml.safe_load(open(reg, encoding="utf-8")) or {}).get("projects") or []
host = socket.gethostname().split(".")[0]

def clone_of(p):
    """This machine's clone of a project: its own clones[] entry first, then local_clone, then a
    repo path under the home or the operator's home. A path that does not exist is NOT a clone."""
    cands = []
    clones = p.get("clones") or {}
    for key in (host, socket.gethostname(), "local"):
        if clones.get(key):
            cands.append(clones[key])
    for key in ("local_clone", "path"):
        if p.get(key):
            cands.append(p[key])
    repo = p.get("repo") or ""
    if repo == ".":
        # `.` is THE TREE THIS DOOR LIVES IN (the registry's own convention), never the home
        cands.append(tree)
    elif repo:
        cands.append(repo if os.path.isabs(repo) else os.path.join(home, repo))
        cands.append(os.path.expanduser("~/" + repo))
    for cand in cands:
        cand = os.path.expanduser(str(cand))
        if os.path.isdir(cand):
            return os.path.realpath(cand)
    return ""

def match(p):
    """A row is the token by id, name, alias, git repo name or repo basename — never a partial."""
    t = token.strip().lower()
    fields = [str(p.get("id", "")), str(p.get("name", "")), str(p.get("repo", "")),
              str((p.get("git") or {}).get("repo", ""))]
    fields += [str(a) for a in (p.get("aliases") or [])]
    fields = [f.lower() for f in fields if f]
    if t in fields:
        return True
    return t in [os.path.basename(f).replace(".git", "") for f in fields]

def by_path(path):
    real = os.path.realpath(path)
    for p in projects:
        clone = clone_of(p)
        if clone and real == clone:
            return p, "registry clone"
        if (p.get("repo") or "") == "." and real == os.path.realpath(tree):
            return p, "this tree"
    # a path inside a clone is still that project's path
    for p in projects:
        clone = clone_of(p)
        if clone and (real == clone or real.startswith(clone + os.sep)):
            return p, "inside the registry clone"
    return None, ""

row = None
how = ""
if os.path.isdir(token):
    row, how = by_path(token)
    path = os.path.realpath(token)
else:
    path = ""
    for p in projects:
        if match(p):
            row = p
            how = "registry id"
            path = clone_of(p)
            if not path:
                sys.stderr.write(
                    f'error: project {p.get("id")} is in the registry but has no clone on {host}\n'
                    f'help: add clones.{host} to its row in {reg}, or pass the path directly\n')
                raise SystemExit(1)
            break
    if row is None and os.path.isdir(os.path.expanduser(token)):
        path = os.path.realpath(os.path.expanduser(token))
        row, how = by_path(path)

if row is not None:
    # an errand is seated in the project's CLONE, never in a subdirectory or a worktree of it
    path = clone_of(row) or path

is_ymir = bool(path) and os.path.realpath(path) == os.path.realpath(tree)
kind = "ymir" if is_ymir else ("other" if row is not None else "unregistered")
pid = (row or {}).get("id") or (os.path.basename(path) if path else token)
name = (row or {}).get("name") or pid

if mode == "row":
    rows = [("path", path), ("id", pid), ("name", name), ("kind", kind),
            ("realm", str((row or {}).get("realm") or "")),
            ("how", how or ("a path, not in the registry" if path else "unresolved")),
            ("clone", path), ("host", host)]
    print("\n".join(f"{k}\t{v}" for k, v in rows))
    raise SystemExit(0)

if mode == "records":
    rec = (row or {}).get("records") or {}
    if not rec:
        sys.stderr.write(
            f'error: {pid} has no records: block in the registry\n'
            f'help: add one under - id: {pid} in {reg} — in_repo (decisions, handoff, schedule, '
            f'plans, plan_status, docs_index), in_home (meetings, seat), boards, merges\n')
        raise SystemExit(3)
    duty = {"in_repo": "in the project's repository — read it before you write; update it before your report",
            "in_home": "in the home — read it before you write; update it before your report",
            "boards": "the board the work is tracked on",
            "worktree": "the project's own worktree convention"}
    for place in ("in_repo", "in_home", "boards"):
        block = rec.get(place) or {}
        if isinstance(block, dict):
            for key, value in block.items():
                print(f"{place}\t{key}\t{value}\t{duty[place]}")
    if rec.get("merges"):
        print(f"merges\tmerges\t{rec['merges']}\twho merges in this project — you open, they seal")
    raise SystemExit(0)

if mode == "worktree":
    wt = (row or {}).get("worktree") or {}
    for key in ("command", "path", "branch"):
        if wt.get(key):
            print(f"{key}\t{wt[key]}")
    print(f"clone\t{path or ''}")
    print(f"id\t{pid}")
    raise SystemExit(0)

sys.stderr.write(f"error: unknown mode {mode}\n")
raise SystemExit(2)
PY
}

# read the resolver's rows into variables, without a second YAML reader
declare -A R=()
read_row() {  # <mode>
  local mode="$1" line key value
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%$'\t'*}"; value="${line#*$'\t'}"
    [ "$key" = "$line" ] && continue
    R["$key"]="$value"
    # the worktree block's own keys, and only when the worktree block was the thing read
    if [ "$mode" = "worktree" ]; then
      [ "$key" = "command" ] && R["wt_command"]="$value"
      [ "$key" = "path" ] && R["wt_path"]="$value"
      [ "$key" = "branch" ] && R["wt_branch"]="$value"
    fi
  done < <(reg_rows "$mode")
}

case "$ACTION" in
  resolve)
    read_row row
    [ -n "${R[path]:-}" ] && [ -d "${R[path]}" ] || {
      printf 'error: %s does not resolve to a directory on this machine\nhelp: bin/agents/project-target.sh resolve <path|id|alias>\n' "$TOKEN" >&2
      exit 1; }
    printf 'path\t%s\nid\t%s\nname\t%s\nkind\t%s\nrealm\t%s\nhow\t%s\nclone\t%s\nhost\t%s\n' \
      "${R[path]}" "${R[id]}" "${R[name]}" "${R[kind]}" "${R[realm]:-}" "${R[how]}" "${R[clone]}" "${R[host]}"
    ;;

  records)
    # print the rows straight through, in the order the reader gave them
    reg_rows records
    ;;

  worktree)
    [ -n "$ID_ARG" ] || { printf 'error: worktree needs an errand id\nhelp: project-target.sh worktree <project> <errand-id>\n' >&2; exit 2; }
    read_row row
    [ -n "${R[path]:-}" ] && [ -d "${R[path]:-}" ] || {
      printf 'error: %s does not resolve to a directory on this machine — nothing to make a worktree in\n' "$TOKEN" >&2
      exit 1; }
    if [ "${R[kind]}" = ymir ]; then
      # This repository's own worktrees belong to the engine and to bin/forge/yggdrasil.sh; this
      # door never makes a second convention for the tree it lives in.
      printf 'worktree\t%s\nbranch\t%s\nhow\t%s\ncreated\t%s\n' "" "" "ymir's own tree — the engine makes the worktree" "no"
      exit 0
    fi
    CLONE="${R[path]}"
    read_row worktree
    WT_REL="${R[wt_path]:-}"; BRANCH="${R[wt_branch]:-}"; WT_CMD="${R[wt_command]:-}"
    # the declared convention, with {id} filled; the defaults exist only where a row says nothing
    WT_REL="${WT_REL:-.yggdrasil/$ID_ARG}"; BRANCH="${BRANCH:-eindri/$ID_ARG}"
    WT_REL="${WT_REL//\{id\}/$ID_ARG}"; BRANCH="${BRANCH//\{id\}/$ID_ARG}"
    case "$WT_REL" in /*) WT="$WT_REL" ;; *) WT="$CLONE/$WT_REL" ;; esac
    made="no"
    if [ "$DRY" = 1 ]; then
      if [ -d "$WT" ] && [ -e "$WT/.git" ]; then made="reused"; else made="would-be-made"; fi
      printf 'worktree\t%s\nbranch\t%s\nhow\t%s\ncreated\t%s\n' "$WT" "$BRANCH" "in the project's own repository" "$made"
      exit 0
    fi
    if [ -d "$WT" ] && [ -e "$WT/.git" ]; then
      made="reused"
    elif [ -n "$WT_CMD" ]; then
      CMD="${WT_CMD//\{id\}/$ID_ARG}"
      out="$(cd "$CLONE" && bash -c "$CMD" 2>&1)"; rc=$?
      if [ "$rc" -ne 0 ]; then
        printf 'error: the project’s own worktree maker failed in %s (exit %s)\n%s\nhelp: decline the seat rather than working in the main tree\n' "$CLONE" "$rc" "$out" >&2
        exit 1
      fi
      if [ -d "$WT" ] && [ -e "$WT/.git" ]; then made="yes"
      else
        printf 'error: %s ran but no worktree stands at %s\nhelp: the row'"'"'s worktree.path does not match its worktree.command — fix the registry row for %s\n' \
          "$WT_CMD" "$WT" "${R[id]}" >&2
        exit 1
      fi
    else
      base="$(git -C "$CLONE" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
      base="${base:-HEAD}"
      out="$(git -C "$CLONE" worktree add -b "$BRANCH" "$WT" "$base" 2>&1)"; rc=$?
      if [ "$rc" -ne 0 ]; then
        printf 'error: could not make a worktree in %s (exit %s)\n%s\nhelp: decline the seat rather than working in the main tree\n' "$CLONE" "$rc" "$out" >&2
        exit 1
      fi
      made="yes"
    fi
    printf 'worktree\t%s\nbranch\t%s\nhow\t%s\ncreated\t%s\n' "$WT" "$BRANCH" "created in the project's own repository" "$made"
    ;;
esac
