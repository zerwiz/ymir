#!/usr/bin/env bash
# warden-lib.sh — the shared law every outward warden keeps (plan 290 §3; the Allfather, 2026-11-14).
#
# WHY. On 2026-11-14 every PR merged into `zerwiz/ymir` was merged as a GitHub account this fleet does
# not own: a merging warden shipped by THIS repo, seated by ROLE on a machine that merely installed it,
# acting on any repository the login could write. The capability is right; the seating and the target
# were wrong. So the law moves into one library that every outward door sources:
#
#   1 · OPT-IN PER MACHINE. A door runs only where `$YMIR_HOME/config/machines/<machine>/wardens.yaml`
#       says `enabled: on`. A fresh install seats nothing; a stranger's install seats nothing.
#   2 · OWN REPOSITORIES ONLY. A door acts on `owner/repo` only when the operator's registry
#       (hodd/identity/projects.yaml) claims that repository. Not listed → refused, by name.
#   3 · ITS MACHINE'S IDENTITY. The login the door would act as (`gh api user`) is compared with the
#       name the machine gives that duty; a mismatch is a refusal that prints both names.
#   4 · EVERY OUTWARD ACT IS A RUNE. Machine, door, identity, repository and the verdict it rested on.
#   5 · A MERGE NEEDS THREE YESES. `merge: on` for the door, the machine the fleet registry names as
#       heart, and `bin/forge/merge-verdict.sh` saying yes. Anything else is a named refusal.
#
# The reader is `bin/forge/warden-policy.py` — one parser, one precedence rule. This file adds no
# opinion of its own: it resolves, it refuses, and it records.
#
# USAGE (a door sources this file, then asks):
#
#   . "$ROOT/bin/forge/warden-lib.sh"
#   warden_begin queue-warden                 # resolve this machine, this door, this identity
#   warden_require_door || exit 3             # a clean skip when the machine does not name the door
#   warden_require_repos "$REPO" || exit 3    # refuse a repository that is not ours
#   warden_require_identity || exit 3         # refuse an identity mismatch, naming both
#   warden_runes acted "read 4 open PRs; cap 5; merges 0"
#   ...
#   warden_merge_allowed 747 || exit 3        # the three yeses, or why one is missing
#
# EXIT CODES: 0 yes · 1 no · 3 refused (the door's own convention: a refusal is not a fault).
set -u

WARDEN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARDEN_ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$WARDEN_LIB_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
WARDEN_POLICY="${WARDEN_POLICY:-$WARDEN_LIB_DIR/warden-policy.py}"
WARDEN_PY="${WARDEN_PY:-python3}"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  [ -r "$WARDEN_ROOT/bin/vault/hoard-lib.sh" ] && . "$WARDEN_ROOT/bin/vault/hoard-lib.sh" && YMIR_HOARD_LIB_LOADED=1
fi

WARDEN_HOME=""
if declare -f ymir_home_root >/dev/null 2>&1; then ymir_home_root WARDEN_HOME 2>/dev/null || WARDEN_HOME=""; fi
[ -n "$WARDEN_HOME" ] || WARDEN_HOME="${YMIR_HOME:-$WARDEN_ROOT}"

WARDEN_DOOR=""
WARDEN_MACHINE=""
WARDEN_HEART=""
WARDEN_IS_HEART=0
WARDEN_IDENTITY_NAMED=""
WARDEN_IDENTITY_ACTUAL=""
WARDEN_IDENTITY_MATCH=0
WARDEN_REPOS=""
WARDEN_SOURCE=""

# ── the one reader ──────────────────────────────────────────────────────────
_warden_policy() {  # <args…> — the reader, and its reason on stderr
  [ -r "$WARDEN_POLICY" ] || { printf 'warden: the policy reader is missing (%s)\n' "$WARDEN_POLICY" >&2; return 127; }
  "$WARDEN_PY" -I "$WARDEN_POLICY" "$@"
}

warden_policy_get() {  # <key> [default] — the door's key, then the machine default, then <default>
  _warden_policy get "${WARDEN_DOOR:-}" "$1" ${2:+--default "$2"} 2>/dev/null
}

warden_policy_machine() {
  WARDEN_MACHINE="$(_warden_policy name 2>/dev/null)"
  WARDEN_HEART="$(_warden_policy heart 2>/dev/null)"
  WARDEN_SOURCE="$(_warden_policy source 2>/dev/null)"
  WARDEN_IS_HEART=0
  [ -n "$WARDEN_MACHINE" ] && [ "$WARDEN_MACHINE" = "$WARDEN_HEART" ] && WARDEN_IS_HEART=1
  [ -n "$WARDEN_MACHINE" ]
}

warden_begin() {  # <door> — resolve the machine and the door once; say what was found
  WARDEN_DOOR="$1"
  warden_policy_machine || { printf 'warden: this machine cannot be named from the fleet registry\n' >&2; return 1; }
  WARDEN_IDENTITY_NAMED="$(warden_policy_get identity "")"
  return 0
}

warden_resolve_line() {  # the whole resolution, one line — what a door prints when asked why
  printf 'warden[6]{door,machine,heart,on,identity,policy}:\n  "%s","%s","%s","%s","%s","%s"\n' \
    "$WARDEN_DOOR" "$WARDEN_MACHINE" "${WARDEN_HEART:-—}" \
    "$(warden_door_on && printf 'on' || printf 'off')" "${WARDEN_IDENTITY_NAMED:-unnamed}" "$WARDEN_SOURCE"
}

# ── 1 · opt-in per machine ─────────────────────────────────────────────────
warden_door_on() {  # 0 when this machine's file names this door on
  [ -n "$WARDEN_DOOR" ] || return 2
  _warden_policy on "$WARDEN_DOOR" >/dev/null 2>&1
}

warden_skip() {  # <why> — the clean skip: a door this machine does not hold is not a fault
  printf '%s: skipped on %s — %s\n' "${WARDEN_DOOR:-warden}" "${WARDEN_MACHINE:-this machine}" "$*"
}

warden_require_door() {  # 0 seated · 1 not seated (with the reason printed)
  local why
  why="$(_warden_policy on "$WARDEN_DOOR" 2>&1 >/dev/null)" || {
    printf '%s: REFUSED on %s — %s\nhelp: name this door in %s (enabled: on) if this machine should run it\n' \
      "$WARDEN_DOOR" "${WARDEN_MACHINE:-this machine}" "${why:-the machine names no such door}" \
      "${WARDEN_SOURCE:-$WARDEN_HOME/config/machines/<machine>/wardens.yaml}" >&2
    return 1
  }
  return 0
}

# ── 2 · own repositories only ──────────────────────────────────────────────
warden_repo_owned() {  # <owner/repo> — 0 when the operator's registry claims it
  _warden_policy owns "$1" >/dev/null 2>&1
}

warden_require_repos() {  # <owner/repo>… — refuse every repository that is not ours
  local repo why rc=0
  for repo in "$@"; do
    [ -n "$repo" ] || continue
    [ "$repo" = "." ] && continue
    if ! why="$(_warden_policy owns "$repo" 2>&1 >/dev/null)"; then
      printf '%s: REFUSED — %s\n' "${WARDEN_DOOR:-warden}" "$why" >&2
      rc=1
    fi
  done
  return $rc
}

warden_repo_of() {  # <checkout> — the `owner/repo` that checkout's origin points at
  local url
  url="$(git -C "$1" remote get-url origin 2>/dev/null)" || return 1
  url="${url%.git}"
  printf '%s' "$url" | awk -F/ 'NF>=2 {print $(NF-1)"/"$NF; found=1} END {exit found?0:1}'
}

warden_require_checkout() {  # <checkout> — the repository a checkout would push to must be ours
  local repo
  repo="$(warden_repo_of "$1")" || {
    printf '%s: REFUSED — %s has no readable origin, so the repository it would push to is unknown\n' \
      "${WARDEN_DOOR:-warden}" "$1" >&2
    return 1
  }
  WARDEN_REPOS="$repo"
  warden_require_repos "$repo" || return 1
  printf '%s' "$repo"
}

# ── 3 · the machine's own identity ─────────────────────────────────────────
warden_gh_login() {  # the login a gh call would act as, or empty
  command -v gh >/dev/null 2>&1 || return 1
  gh api user --jq .login 2>/dev/null || gh api user 2>/dev/null | sed -n 's/.*"login"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

warden_require_identity() {  # 0 match (or unnamed) · 1 a mismatch, both names printed
  WARDEN_IDENTITY_ACTUAL="$(warden_gh_login || true)"
  if [ -z "$WARDEN_IDENTITY_ACTUAL" ]; then
    printf '%s: REFUSED on %s — no GitHub identity answers (gh api user), so the door cannot prove whose hand it is\n' \
      "${WARDEN_DOOR:-warden}" "${WARDEN_MACHINE:-this machine}" >&2
    return 1
  fi
  if [ -z "$WARDEN_IDENTITY_NAMED" ]; then
    # An unnamed duty is not a matched one: the record says so, and the door says so once.
    WARDEN_IDENTITY_MATCH=0
    printf '%s: %s acts as the ambient login %s — this machine names no identity for this duty (plan 290 P5)\n' \
      "${WARDEN_DOOR:-warden}" "${WARDEN_MACHINE}" "$WARDEN_IDENTITY_ACTUAL" >&2
    return 0
  fi
  if [ "$WARDEN_IDENTITY_ACTUAL" != "$WARDEN_IDENTITY_NAMED" ]; then
    printf '%s: REFUSED on %s — this duty is named %s but gh would act as %s\nhelp: sign in as %s, or name the machine\x27s identity honestly in %s\n' \
      "${WARDEN_DOOR:-warden}" "$WARDEN_MACHINE" "$WARDEN_IDENTITY_NAMED" "$WARDEN_IDENTITY_ACTUAL" \
      "$WARDEN_IDENTITY_NAMED" "$WARDEN_SOURCE" >&2
    return 1
  fi
  WARDEN_IDENTITY_MATCH=1
  return 0
}

warden_token_ref() { warden_policy_get token_ref ""; }

warden_token() {  # the token for the identity named for this duty, if the vault holds it
  local ref val
  ref="$(warden_token_ref)"
  [ -n "$ref" ] || return 1
  [ -x "$WARDEN_ROOT/bin/vault/hodd.sh" ] || return 1
  val="$("$WARDEN_ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | sed -n "s/^\(export \)\{0,1\}${ref}=//p" | tail -1)"
  [ -n "$val" ] || return 1
  printf '%s' "$val"
}

# ── 4 · every outward act is a Rune ────────────────────────────────────────
warden_runes() {  # <event> <message> — machine, door, identity, repository, verdict
  local event="$1"; shift
  local msg="$*" row
  row="machine=${WARDEN_MACHINE:-unknown} door=${WARDEN_DOOR:-warden} identity=${WARDEN_IDENTITY_ACTUAL:-none}${WARDEN_IDENTITY_NAMED:+ named=${WARDEN_IDENTITY_NAMED}} repos=${WARDEN_REPOS:-none} :: ${msg}"
  if [ -x "$WARDEN_ROOT/bin/records/runes-append.sh" ]; then
    bash "$WARDEN_ROOT/bin/records/runes-append.sh" "${WARDEN_DOOR:-warden}" "$event" --message "$row" >/dev/null 2>&1 \
      || printf 'warden: the Rune could not be carved for %s\n' "$event" >&2
  fi
  printf '%s\n' "$row"
}

# ── 5 · a merge needs three yeses ──────────────────────────────────────────
warden_merge_allowed() {  # <pr> — 0 allowed · 1 refused, every missing yes named
  local pr="$1" merge verdict="" rc=0
  merge="$(warden_policy_get merge off)"
  merge="$(printf '%s' "$merge" | tr 'A-Z' 'a-z')"
  if [ "$merge" != "on" ]; then
    printf '%s: merge refused — %s.merge is %s (absent reads as off)\n' "${WARDEN_DOOR:-warden}" "$WARDEN_DOOR" "${merge:-off}" >&2
    rc=1
  fi
  if [ "$WARDEN_IS_HEART" != 1 ]; then
    printf '%s: merge refused — this machine is %s and the fleet names %s as the heart; only the heart may say merge: on (plan 290 P1)\n' \
      "${WARDEN_DOOR:-warden}" "${WARDEN_MACHINE:-unknown}" "${WARDEN_HEART:-no machine}" >&2
    rc=1
  fi
  if [ -x "$WARDEN_ROOT/bin/forge/merge-verdict.sh" ]; then
    bash "$WARDEN_ROOT/bin/forge/merge-verdict.sh" "$pr" >/dev/null 2>&1 || {
      printf '%s: merge refused — bin/forge/merge-verdict.sh did not answer yes for PR %s\n' "${WARDEN_DOOR:-warden}" "$pr" >&2
      rc=1
    }
  else
    printf '%s: merge refused — bin/forge/merge-verdict.sh is not in this tree, so no verdict exists for PR %s\n' \
      "${WARDEN_DOOR:-warden}" "$pr" >&2
    rc=1
  fi
  [ "$rc" = 0 ] && verdict="yes" || verdict="no"
  WARDEN_REPOS="${WARDEN_REPOS:-none}"
  return $rc
}

# ── seating: does install/update put this door's clock on this machine? ────
warden_seat_allowed() {  # <door> — used by --install-timer paths and by bin/engine/units.py
  local door="$1" why
  if why="$("$WARDEN_PY" -I "$WARDEN_POLICY" on "$door" 2>&1 >/dev/null)"; then
    return 0
  fi
  printf '%s: not seated — %s\n' "$door" "${why:-the machine names no such door}" >&2
  return 1
}

warden_bad_reason() { printf '%s: %s\n' "${WARDEN_DOOR:-warden}" "$*" >&2; }
