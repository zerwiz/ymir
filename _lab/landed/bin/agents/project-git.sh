#!/usr/bin/env bash
# project-git.sh — resolve a project's GitHub block from the master registry
# (`registry/projects.yaml`). The runtime consumes this instead of guessing a
# remote. Auth is a REFERENCE (app|pat|ssh|gh), never a value.
#
# A project row names its REALM (`realm:`), which is what `workspace:` meant
# before plan 62 — that key still resolves, through bin/skuld/registry-lib.sh, and every
# use of it is named out loud on stderr. Never resolve the realm key here.
#
# Usage:
#   project-git.sh <project-id> [--field host|owner|repo|remote|default_branch|auth|machine|realm]
#   project-git.sh list
#   project-git.sh paths                 # id<TAB>state<TAB>path for every row — ONE resolver
#   project-git.sh <id> --field path|clone
#   project-git.sh doctor [--probe] [--strict] [--json]
#   project-git.sh --version
set -u

VERSION="1.4.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
# shellcheck source=bin/skuld/registry-lib.sh
. "$SCRIPT_DIR/../skuld/registry-lib.sh"
REG="$(registry_projects_file)"

# work_path — where a project's tree IS, or where a clone of it WOULD land (plan 210 P3).
# The order is fixed and small on purpose: the row's own `repo:` path under the code tree, the
# operator's home, then the private home; and when none of those exists, the canonical hall
# $YMIR_HOME/halls/<owner>/<repo>. No other guess is made, and `clone` writes to exactly the
# path this prints — so the door and the diagnosis can never disagree.
YH=""
if declare -f ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YH 2>/dev/null || YH=""
fi
[ -n "$YH" ] || YH="${YMIR_HOME:-}"
work_path() {  # <owner> <repo-name> <row-path> <mode: exist|hall>
  local owner="$1" name="$2" row="$3" mode="${4:-exist}" c
  if [ -n "$row" ] && [ "$row" != "null" ]; then
    if [ "${row#/}" != "$row" ]; then
      [ -d "$row" ] && { printf '%s' "$row"; return 0; }
    else
      for base in "$ROOT" "$HOME" "$YH"; do
        [ -n "$base" ] || continue
        c="$base/$row"
        [ -d "$c" ] && { printf '%s' "$(cd "$c" && pwd)"; return 0; }
      done
    fi
  fi
  [ -n "$owner" ] && [ -n "$name" ] || return 1
  c="${YH:-$HOME/.ymir}/halls/$owner/$name"
  if [ "$mode" = hall ]; then printf '%s' "$c"; return 0; fi
  [ -d "$c" ] && { printf '%s' "$c"; return 0; }
  return 1
}

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ID="${1-}"; shift || true

# doctor — the registry's own truth, before anything claims a repo is workable.
# WHY (plan 210 P0): measured 2026-11-06 — of 78 registered projects, 56 could not name a
# remote and 67 had no local clone, so "add the user's repos" was unbuildable until the
# registry could say which of its own rows are real. This is a DIAGNOSIS: it reads the
# registry and the disk, writes nothing, and is offline by default (a probe is asked for).
if [ "$ID" = doctor ]; then
  PROBE=0; STRICT=0; JSON=0
  while [ $# -gt 0 ]; do case "$1" in
    --probe) PROBE=1; shift ;; --strict) STRICT=1; shift ;; --json) JSON=1; shift ;;
    -*) printf 'error: unknown flag %s\nhelp: project-git.sh doctor [--probe] [--strict] [--json]\n' "$1" >&2; exit 2 ;;
    *) shift ;;
  esac; done
  HOME_DIR=""
  if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
    for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
      [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
    done; unset _c
  fi
  declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR 2>/dev/null
  # NEVER A GUESSED HOME (Rule 07, and defaults-guard says so). No resolver answer means the
  # clone lookup simply has no home to look under — the rows still print, and each one says so.
  [ -n "$HOME_DIR" ] || { printf 'note: the home is unresolved — clone lookup covers the code tree only\nhelp: bin/vault/hoard-lib.sh names the home\n' >&2; HOME_DIR=""; }
  [ -f "$REG" ] || { printf 'error: registry not found: %s\nhelp: bin/engine/ymir-install.sh\n' "$REG" >&2; exit 1; }
  PATHS_FILE="$(mktemp)"
  trap 'rm -f "$PATHS_FILE"' EXIT
  bash "$0" paths >"$PATHS_FILE" 2>/dev/null
  python3 - "$REG" "$ROOT" "$HOME" "$HOME_DIR" "$PROBE" "$STRICT" "$JSON" "$PATHS_FILE" <<'PY'
import json, os, subprocess, sys

reg, root, home, ymir_home, probe, strict, as_json, paths_file = sys.argv[1:9]
# ONE RESOLVER. Where a project's tree is (or where a clone would land) is decided by
# `project-git.sh paths`; this diagnosis reads that answer and never re-derives it.
paths = {}
try:
    for line in open(paths_file, encoding="utf-8"):
        pid, state, path = (line.rstrip("\n").split("\t") + ["", ""])[:3]
        paths[pid] = (state, path)
except OSError:
    pass
probe, strict, as_json = probe == "1", strict == "1", as_json == "1"
try:
    import yaml
except ImportError:
    sys.stderr.write("project-git doctor: pyyaml missing — the registry is YAML\n")
    raise SystemExit(1)

rows = [r for r in ((yaml.safe_load(open(reg, encoding="utf-8")) or {}).get("projects") or [])
        if isinstance(r, dict) and r.get("id")]


def git_block(row):
    g = row.get("git") or {}
    owner = str(g.get("owner") or "").strip()
    repo = str(g.get("repo") or "").strip()
    missing = [k for k, v in (("owner", owner), ("repo", repo)) if not v or v == "?"]
    if not owner and not repo:
        return "no-git", missing, ""
    if missing:
        return "partial", missing, ""
    return "ok", [], f"{owner}/{repo}"


def find_clone(row):
    state, path = paths.get(row.get("id"), ("none", "-"))
    return path if state == "here" else "-"


def probe_repo(name):
    try:
        out = subprocess.run(
            ["gh", "repo", "view", name, "--json", "isArchived,hasIssuesEnabled,defaultBranchRef"],
            capture_output=True, text=True, timeout=25, check=False)
    except FileNotFoundError:
        return "no-gh", "unknown"
    except subprocess.TimeoutExpired:
        return "timeout", "unknown"
    if out.returncode != 0:
        return "missing", "unknown"
    try:
        meta = json.loads(out.stdout or "{}")
    except json.JSONDecodeError:
        return "unreadable", "unknown"
    if meta.get("isArchived"):
        return "archived", "on" if meta.get("hasIssuesEnabled") else "off"
    return "reachable", "on" if meta.get("hasIssuesEnabled") else "off"


out, findings, counts = [], [], {"rows": len(rows), "git-ok": 0, "git-missing": 0,
                                "cloned": 0, "no-clone": 0, "ready": 0, "far": 0}
for row in rows:
    state, missing, name = git_block(row)
    clone = find_clone(row)
    remote, issues = "-", "-"
    if name:
        counts["git-ok"] += 1
    else:
        counts["git-missing"] += 1
    if clone != "-":
        counts["cloned"] += 1
    elif name:
        counts["no-clone"] += 1
        findings.append({"id": row["id"], "why": "names a remote but has no local clone — readable, not workable"})
    if state != "ok":
        findings.append({"id": row["id"], "why": "git{} is " + ("absent" if state == "no-git" else "partial (" + ", ".join(missing) + " unset)")})
    if name and probe:
        remote, issues = probe_repo(name)
    if name and remote == "-":
        verdict = "ready" if clone != "-" else "far"
    elif name:
        verdict = {"reachable": "ready" if clone != "-" else "far",
                   "archived": "archived"}.get(remote, "unreachable")
        if verdict == "unreachable":
            findings.append({"id": row["id"], "why": f"{name} is not reachable — {remote}"})
    else:
        verdict = "no-git"
    counts[verdict] = counts.get(verdict, 0) + 1
    out.append({"id": row["id"], "realm": row.get("realm") or row.get("workspace") or "?",
                "git": state, "clone": clone, "remote": remote, "issues": issues, "verdict": verdict})

summary = {"rows": counts["rows"], "git-ok": counts["git-ok"], "git-missing": counts["git-missing"],
           "cloned": counts["cloned"], "no-clone": counts["no-clone"], "probe": "on" if probe else "off"}
if as_json:
    print(json.dumps({"rows": out, "findings": findings, "summary": summary}, indent=1))
else:
    print(f"registry[{len(out)}]{{id,realm,git,clone,remote,issues,verdict}}:")
    for r in out:
        print('  "%s","%s","%s","%s","%s","%s","%s"' % (
            r["id"], r["realm"], r["git"], r["clone"], r["remote"], r["issues"], r["verdict"]))
    if findings:
        print(f"findings[{len(findings)}]{{id,why}}:")
        for f in findings:
            print('  "%s","%s"' % (f["id"], f["why"].replace('"', "'")))
    print(f"summary[{len(summary)}]{{key,value}}:")
    for k, v in summary.items():
        print('  "%s","%s"' % (k, v))

if strict and any(r["verdict"] in ("no-git", "unreachable") for r in out):
    sys.stderr.write("project-git doctor: the registry cannot name or reach a remote for at least one row "
                     "— the findings above name each one\n")
    raise SystemExit(1)
PY
  exit $?
fi
FIELD=""
while [ $# -gt 0 ]; do case "$1" in --field) FIELD=${2-}; shift 2 ;; *) shift ;; esac; done
[ -f "$REG" ] || { printf 'error: registry not found: %s\nhelp: run bin/engine/ymir-install.sh\n' "$REG" >&2; exit 1; }

if [ "$ID" = "paths" ]; then
  # id<TAB>state<TAB>path — state is `here` (the tree exists) or `hall` (where a clone WOULD land).
  while IFS= read -r line; do
    case "$line" in "--- "*) ;; *) continue ;; esac
    line="${line#--- }"
    pid="${line%%$'\t'*}"; rest="${line#*$'\t'}"
    powner="${rest%%$'\t'*}"; rest="${rest#*$'\t'}"
    pname="${rest%%$'\t'*}"; prow="${rest#*$'\t'}"
    if p="$(work_path "$powner" "$pname" "$prow" exist)"; then
      printf '%s\there\t%s\n' "$pid" "$p"
    elif p="$(work_path "$powner" "$pname" "$prow" hall)"; then
      printf '%s\thall\t%s\n' "$pid" "$p"
    else
      printf '%s\tnone\t-\n' "$pid"
    fi
  done < <(python3 - "$REG" <<'PY0'
import sys, yaml
rows = [r for r in ((yaml.safe_load(open(sys.argv[1], encoding="utf-8")) or {}).get("projects") or [])
        if isinstance(r, dict) and r.get("id")]
for r in rows:
    g = r.get("git") or {}
    print("--- %s\t%s\t%s\t%s" % (r["id"], g.get("owner") or "", g.get("repo") or "",
                                   (r.get("repo") or "") if isinstance(r.get("repo"), str) else ""))
PY0
)
  exit 0
fi

if [ "$ID" = "list" ]; then
  n=$(grep -cE '^\s*-\s+id:' "$REG" 2>/dev/null || echo 0)
  if [ "$FIELD" = "about" ]; then
    printf 'projects[%s]{id,about}:\n' "$n"
    awk '
      /^[[:space:]]*-[[:space:]]+id:/ { sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, ""); id=$0 }
      /^[[:space:]]*about:/ { sub(/^[[:space:]]*about:[[:space:]]*"/, ""); sub(/"[[:space:]]*$/, ""); if (id != "") printf "  \"%s\",\"%s\"\n", id, $0 }
    ' "$REG"
    exit 0
  fi
  printf 'projects[%s]{id}:\n' "$n"
  grep -E '^\s*-\s+id:' "$REG" | sed -E 's/^\s*-\s+id:\s*/  "/; s/\s*$/" /'
  exit 0
fi
[ -n "$ID" ] || { printf 'error: needs a project id\nhelp: bin/agents/project-git.sh <project-id> [--field owner]\n' >&2; exit 2; }

block="$(awk -v id="$ID" '
  $0 ~ "^[[:space:]]*-[[:space:]]+id:[[:space:]]*"id"[[:space:]]*$" {f=1; next}
  f && /^[[:space:]]*-[[:space:]]+id:/ {exit}
  f {print}
' "$REG")"
[ -n "$block" ] || { printf 'error: project not found: %s\nhelp: bin/agents/project-git.sh list\n' "$ID" >&2; exit 1; }

gitline="$(printf '%s\n' "$block" | grep -m1 'git:')"
# BOTH SHAPES. Measured 2026-11-06: the operator's registry writes the block NESTED —
#   git:
#     host: github.com
# and this reader only ever parsed the INLINE form (`git: {host: …}`), so every field came
# back EMPTY for every row and four consumers (`mjollnir`, `yggdrasil`, `github-deploy`,
# `clone`) were resolving a remote out of nothing. A field read that cannot fail loudly is
# how a door returns "" and the caller carries on.
val() {
  printf '%s\n' "$block" | python3 -c '
import re, sys
key = sys.argv[1]
lines = sys.stdin.read().splitlines()
for i, line in enumerate(lines):
    if re.match(r"^\s*git:\s*\{", line):
        m = re.search(key + r"\s*:\s*([^,}]+)", line)
        print((m.group(1).strip().strip(chr(34) + chr(39)) if m else ""))
        break
    if re.match(r"^\s*git:\s*$", line):
        indent = len(line) - len(line.lstrip())
        for nxt in lines[i + 1:]:
            if not nxt.strip():
                continue
            if len(nxt) - len(nxt.lstrip()) <= indent:
                break
            m = re.match(r"^\s+([A-Za-z_]+):\s*(.*)$", nxt)
            if m and m.group(1) == key:
                print(m.group(2).strip().strip(chr(34) + chr(39)))
                break
        break
' "$1"
}
# non-git top-level keys resolve from the block itself, not the git line
blockval() { printf '%s' "$block" | sed -nE "s/^[[:space:]]*$1:[[:space:]]*([^,}]+).*/\1/p" | head -1 | tr -d ' '; }

host="$(val host)"; owner="$(val owner)"; repo="$(val repo)"; remote="$(val remote)"; br="$(val default_branch)"; auth="$(val auth)"
machine="$(blockval machine)"; company="$(blockval company)"; realm="$(registry_realm "$block" "$ID" "$REG")"
about="$(printf '%s' "$block" | sed -nE 's/^[[:space:]]*about:[[:space:]]*"(.*)"[[:space:]]*$/\1/p' | head -1)"
if [ -n "$FIELD" ]; then
  case "$FIELD" in
    host) printf '%s\n' "$host" ;; owner) printf '%s\n' "$owner" ;; repo) printf '%s\n' "$repo" ;;
    remote) printf '%s\n' "$remote" ;; default_branch) printf '%s\n' "$br" ;; auth) printf '%s\n' "$auth" ;;
    machine) printf '%s\n' "$machine" ;; company) printf '%s\n' "$company" ;; realm) printf '%s\n' "$realm" ;;
    workspace) printf 'deprecated-field: --field workspace is `realm` (plan 62); it still resolves.\n' >&2; printf '%s\n' "$realm" ;;
    about) printf '%s\n' "$about" ;;
    # Two different `repo`s, named out loud so no caller has to guess which it holds:
    # the row's top-level `repo:` is the PATH, the git block's `repo` is the NAME on GitHub.
    # An empty answer is a REFUSAL, not a blank line: a caller that gets "nothing" and keeps
    # going clones into the current directory, which is how a repo lands in a hall it never earned.
    path)  work_path "$owner" "$repo" "$(blockval repo)" exist || {
             printf 'error: %s has no tree on this machine\nhelp: bin/forge/mjollnir.sh clone %s\n' "$ID" "$ID" >&2; exit 1; } ;;
    clone) work_path "$owner" "$repo" "$(blockval repo)" hall || {
             printf 'error: %s cannot name a remote, so it cannot be cloned\nhelp: give the row a git{} block (bin/agents/project-git.sh doctor names it)\n' "$ID" >&2; exit 1; } ;;
    *) printf 'error: unknown field %s\n' "$FIELD" >&2; exit 2 ;;
  esac
  exit 0
fi
printf 'project[1]{id,host,owner,repo,remote,default_branch,auth,machine,company,realm}:\n'
printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' "$ID" "$host" "$owner" "$repo" "$remote" "$br" "$auth" "$machine" "$company" "$realm"
