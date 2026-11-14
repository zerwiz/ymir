#!/usr/bin/env bash
# guards.sh — every TREE ward, in one command.
#
# The pre-push hook and BOTH CI hosts call this, so the set of wards has exactly one home:
# adding a ward means adding a line here, and nowhere else. A ward judges the tree and exits
# non-zero when it finds a fault; this only aggregates.
#
# TWO POSTURES, ONE LIST (plan 243 parts B/C/D/F, 2026-11-11):
#
#   guards.sh                 the PRE-PUSH posture: the diff is the scope, the wards run
#                             CONCURRENTLY under a hard time budget, a whole-tree ward that
#                             is too slow for a push is CI's, and a finding in a file this
#                             push did not touch is printed `inherited` — it never blocks.
#   guards.sh --full          the CI posture: EVERY ward, the WHOLE tree, no budget, no
#                             cache, nothing inherited. This is the binding gate; the
#                             pre-push posture is the fast filter in front of it.
#
# Usage:
#   guards.sh                  # the pre-push posture (diff-scoped, parallel, budgeted)
#   guards.sh --full           # the CI posture (every ward, whole tree)
#   guards.sh --list           # name them
#   guards.sh --profile        # pre-push posture + each ward's time, slowest first
#   guards.sh --base <ref>     # the base the changed set is taken from (default origin/main)
#   guards.sh --changed <file> # read the changed paths from a file (one per line)
#
# Environment:
#   YMIR_PREPUSH_BUDGET   seconds the pre-push posture may spend (default 60)
#   YMIR_GUARD_JOBS       wards run at once (default 8)
#   YMIR_GUARD_CACHE      cache directory (default <git-common-dir>/ymir-guard-cache)
#   YMIR_GUARD_NO_CACHE=1 never read or write the cache
#
# Exit: 0 every ward clean (or every finding is inherited) · 1 a ward found a fault · 2 usage.
#
# WHY THE OLD SHAPE WAS 10–20 MINUTES (measured 2026-11-11, this machine):
#   21 tree wards ran one after another, each walking the WHOLE tree — public-data-guard
#   alone read 5,460 files, inventory-guard 77.9 s, registers-guard 60 s+ — and a push
#   was refused for a fault that was already red on origin/main, in a file it never
#   touched. So the fastest road became --no-verify, and the gate guarded nothing.
set -u

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"
cd "$ROOT" || exit 2

# ONE list. A new tree ward appears here or it does not run anywhere.
WARDS=(runtime-guard.sh unit-writer-guard.sh runtime-pinned-guard.sh defaults-guard.sh app-folder-guard.sh app-functional-guard.sh rules-number-guard.sh inventory-guard.sh registers-guard.sh fleet-version-guard.sh subsystem-docs-guard.sh path-ledger-guard.sh path-legality-guard.sh packaging-guard.sh public-data-guard.sh cron-guard.sh features-guard.sh weave-guard.sh vault-guard.sh confidential-guard.sh dead-code-guard.sh docs-claims-guard.sh home-contract-guard.sh language-guard.sh pkill-guard.sh skills-share-guard.sh rules-compliance-guard.sh pr-ship-guard.sh model-rows-guard.sh areas-guard.sh desktop-main-guard.sh house-colour-guard.sh pr-identity-guard.sh nda-guard.sh hearth-guard.sh)
#
# nda-guard (2026-11-12, RULES/04): company, client and NDA-project names never enter the public tree. The
# names are read from $YMIR_HOME at run time, so the ward is never cached and says UNARMED, aloud, where no
# home resolves. It is in the one list so pre-push and CI both run it.
#
# weave-guard (2026-11-04, plan 175 §3): the weaver was seated and NOTHING CALLED IT — so a stale
# index (RULES/README.md, a plan row, a feature page's catalogue row) was refused by no ward at all.
# It runs weave.sh --check and refuses, naming the gap; it never fixes, because a silent fix hides
# the hand-edit that caused the drift. The hook is convenience, CI keeps the last word.
#
# skills-share-guard (2026-11-04, plan 184): the skills door serves a BUILT copy, and a redaction
# pass trusted to be complete is how a hostname leaves in a footnote. The ward refuses machine
# paths, addresses, LAN hosts, ports, our people, mailboxes, phones, bench tables and our catalog's
# model ids over `hodd/skills-share/published/` — the last word is a refusal, not a review. It
# skips cleanly (and says so) on a machine that has published nothing yet.
# path-legality-guard (2026-11-03): a tracked NAME must be legal on every host RULES/05 claims —
# a `:` NTFS cannot hold made a Windows clone write no tree at all, for a month, unseen.
# packaging-guard (2026-11-03): every path a shipped installer names must exist — the Windows
# .nsi still named the OLD bootstrapper path after Rule 22 moved the host layers, and the build
# that would have said so (ymir-installers.yml) runs only on a tag nobody had cut.

# ── the three postures of a ward ─────────────────────────────────────────────
# SCOPED — the ward takes the changed paths as arguments and judges ONLY those, so a
#          finding it prints is, by construction, the push's own. These are the wards that
#          read file CONTENT (RULES/04 above all: 5,460 files, and the scan is the same
#          answer per file, so a push that changed one file need not re-read 5,459).
SCOPED=(public-data-guard.sh house-colour-guard.sh nda-guard.sh)
# house-colour-guard (2026-11-12, RULES/54): no blue and no purple. Scoped, because the verdict
# is per file — a push that touched three stylesheets needs those three read, not the 24 s the
# whole tree costs; CI's --full reads every file.

# CI_ONLY — declared whole-tree work that costs more than a push may spend (plan 243 §3,
#          part C). Measured on heimdall 2026-11-11, serially, on this tree; the number in
#          each reason is that measurement and `--profile` re-measures it. A ward lands
#          here only with a reason, and CI runs EVERY one of them on every PR and on main
#          (`guards.sh --full`), so nothing is skipped — it is *moved* to the gate with the
#          time to spend. The line is the Allfather's: a ward over 10 s on a typical diff
#          is CI's.
CI_ONLY_REASON=(
  "inventory-guard.sh|77.9s|the bin/ register is re-derived from every folder in the tree, so it is a whole-tree read by construction"
  "registers-guard.sh|201.4s|every generated register is re-derived from the tree; a push cannot scope a derived file the other hand's branch may also have moved"
  "docs-claims-guard.sh|37.2s|Rule 27 reads every user-facing page at once (README, FEATURES, docs/, RULES/, .agents/agents/); the claim set is the whole shelf, not the file"
  "language-guard.sh|22.7s|Rule 43 builds the allow list and reads every document and brief in the tree before it judges one line"
  "dead-code-guard.sh|14.0s|the usage index is one multi-pattern pass over the whole tree; a single file cannot say whether a name is reached elsewhere"
)
# PR_ONLY — a ward that judges a PULL REQUEST, not a tree. It cannot answer before the PR
# exists, so the pre-push and --full both name it and skip it, and the workflow runs it with
# `--ci` (the only mode it can answer in). It was in the tree list until 2026-11-11 and had
# been failing every run with `no pull requests found for branch "check"` — a gate that could
# only ever say no.
PR_ONLY_REASON=(
  "pr-identity-guard.sh|it judges a pull request body; the workflow runs it with --ci, which is the only way it can answer"
)

case "${1-}" in
  -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --list)    printf '%s\n' "${WARDS[@]}"; exit 0 ;;
esac

FULL=0; PROFILE=0; BASE=""; CHANGED_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --full)     FULL=1; shift ;;
    --profile)  PROFILE=1; shift ;;
    --base)     BASE="${2:?--base needs a ref}"; shift 2 ;;
    --changed)  CHANGED_FILE="${2:?--changed needs a path}"; shift 2 ;;
    -v|-V|--version) printf '1.1.0\n'; exit 0 ;;
    *) printf 'error: unknown flag %s\nhelp: guards.sh [--full|--profile|--list|--base REF|--changed FILE]\n' "$1" >&2; exit 2 ;;
  esac
done

BUDGET="${YMIR_PREPUSH_BUDGET:-60}"
JOBS="${YMIR_GUARD_JOBS:-8}"
case "$BUDGET" in ''|*[!0-9]*) BUDGET=60 ;; esac
case "$JOBS"  in ''|*[!0-9]*|0) JOBS=8 ;; esac
[ "$FULL" -eq 1 ] && BUDGET=0        # 0 = no budget

ci_only_reason() {  # <ward> → prints the reason, or nothing
  local row
  for row in "${CI_ONLY_REASON[@]}"; do
    [ "${row%%|*}" = "$1" ] || continue
    local rest="${row#*|}"; local secs="${rest%%|*}"
    printf '%s' "${rest#*|} (measured ${secs} serially on this tree, heimdall 2026-11-11)"
    return 0
  done
  return 1
}
pr_only_reason() {
  local row
  for row in "${PR_ONLY_REASON[@]}"; do
    [ "${row%%|*}" = "$1" ] && { printf '%s' "${row#*|}"; return 0; }
  done
  return 1
}
is_ci_only() { ci_only_reason "$1" >/dev/null; }
is_pr_only() { pr_only_reason "$1" >/dev/null; }
is_scoped()  { local w; for w in "${SCOPED[@]}"; do [ "$w" = "$1" ] && return 0; done; return 1; }

# ── the diff is the scope (plan 243 §3, part B) ──────────────────────────────
# The set a push ADDS: what HEAD carries that the base does not. Untracked files that are
# about to be pushed are added by the caller (the hook passes --changed), because only the
# hook knows what is staged for the push.
resolve_base() {
  [ -n "$BASE" ] && { printf '%s' "$BASE"; return 0; }
  local b
  for b in origin/main origin/master; do
    git rev-parse -q --verify "$b" >/dev/null 2>&1 && { printf '%s' "$b"; return 0; }
  done
  git rev-parse -q --verify '@{upstream}' >/dev/null 2>&1 && { printf '%s' '@{upstream}'; return 0; }
  return 1
}

CHANGED_LIST="$(mktemp "${TMPDIR:-/tmp}/guard-scope-XXXXXX")"
SCOPE_NOTE=""
if [ -n "$CHANGED_FILE" ]; then
  cat "$CHANGED_FILE" >"$CHANGED_LIST" 2>/dev/null || true
fi
if [ "$FULL" -eq 0 ]; then
  if b="$(resolve_base)"; then
    git diff --name-only --no-renames "$b"..HEAD 2>/dev/null >>"$CHANGED_LIST" || true
    git diff --name-only --no-renames --cached 2>/dev/null >>"$CHANGED_LIST" || true
    git diff --name-only --no-renames 2>/dev/null >>"$CHANGED_LIST" || true
    git ls-files --others --exclude-standard >>"$CHANGED_LIST" 2>/dev/null || true
    sort -u "$CHANGED_LIST" -o "$CHANGED_LIST"
  else
    SCOPE_NOTE="no base ref — the whole tree is judged (a first push has no diff to scope)"
  fi
fi
SCOPE_COUNT="$(wc -l < "$CHANGED_LIST" | tr -d ' ')"
[ "$FULL" -eq 1 ] && SCOPE_COUNT=0

# ── the cache (plan 243 §3, part F) ──────────────────────────────────────────
# A ward's verdict is cached against the CONTENT it judged: the ward's own source, the .py
# engines it may exec, the tree digest, and (for a scoped ward) the content hash of every
# file in its scope. An unchanged file is therefore never re-scanned, and a changed one
# always is. A ward declares its own purity with a `# cache: tree` line — a ward that reads
# $YMIR_HOME, the clock, the network or a running service is NOT pure and is never cached,
# because a cache that hides a real finding is the one thing this house does not ship.
CACHE="${YMIR_GUARD_CACHE:-$(git rev-parse --git-common-dir 2>/dev/null || printf '.git')/ymir-guard-cache}"
DIRTY=0
[ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY=1
if [ "$FULL" -eq 1 ] || [ "$DIRTY" -eq 1 ] || [ "${YMIR_GUARD_NO_CACHE:-0}" = 1 ]; then
  CACHE_OK=0
else
  CACHE_OK=1
  mkdir -p "$CACHE" 2>/dev/null || CACHE_OK=0
fi
ENGINE_HASH="$( { cat bin/gates/guards/*.py 2>/dev/null; } | sha256sum | cut -d' ' -f1)"
TREE_HASH="$(git ls-files -s 2>/dev/null | sha256sum | cut -d' ' -f1)"
scope_hash() {  # the content of what a SCOPED ward will read
  local p h
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ -f "$ROOT/$p" ]; then
      h="$(sha256sum "$ROOT/$p" 2>/dev/null | cut -d' ' -f1)"
      printf '%s:%s\n' "$p" "$h"
    else
      printf '%s:absent\n' "$p"
    fi
  done <"$CHANGED_LIST" | sha256sum | cut -d' ' -f1
}
SCOPE_HASH=""
[ "$SCOPE_COUNT" -gt 0 ] && SCOPE_HASH="$(scope_hash)"
cache_key() {  # <ward>
  local w="$1" self hash
  self="$(sha256sum "$ROOT/bin/gates/guards/$w" 2>/dev/null | cut -d' ' -f1)"
  if is_scoped "$w"; then hash="scoped:$SCOPE_HASH"; else hash="tree:$TREE_HASH"; fi
  printf '%s:%s:%s' "$self" "$hash" "$ENGINE_HASH" | sha256sum | cut -d' ' -f1
}
cache_read() {  # <ward> <key> → 0 hit
  [ "$CACHE_OK" -eq 1 ] || return 1
  local f="$CACHE/$1.pass"
  [ -r "$f" ] || return 1
  [ "$(cat "$f" 2>/dev/null)" = "$2" ] || return 1
  return 0
}
cache_write() {  # <ward> <key>
  [ "$CACHE_OK" -eq 1 ] || return 0
  printf '%s' "$2" >"$CACHE/$1.pass" 2>/dev/null || true
}

# ── inherited: a finding in a file this push did not touch is not this push's ─
# Rule 5 of the new gate (plan 243 §3, part D). The ward prints its findings; if none of the
# paths it names is in the changed set, the fault was already there before this branch, and
# refusing the push punishes the wrong hand — the deadlock the old gate never escaped.
# CI refuses it, and names the commit that broke main. A SCOPED ward is never inherited: it
# was handed only the changed files, so anything it finds is ours.
inherited() {  # <ward> <output>
  local w="$1" out="$2" p
  # A ward that was handed ONLY the changed files cannot have found anything else: whatever
  # it prints is this push's. Only a whole-tree run can be inherited.
  if is_scoped "$w" && [ "$SCOPE_COUNT" -gt 0 ]; then return 1; fi
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$out" in *"$p"*) return 1 ;; esac
  done <"$CHANGED_LIST"
  return 0
}

# ── run the wards (plan 243 §3, part C: concurrent, budgeted) ────────────────
RESULTS="$(mktemp -d "${TMPDIR:-/tmp}/guard-results-XXXXXX")"
START_ALL="$(date +%s%N)"
DEADLINE=0
[ "$BUDGET" -gt 0 ] && DEADLINE=$(( $(date +%s) + BUDGET ))
DEFERRED=()

run_ward() {  # <ward>
  local w="$1" s="$ROOT/bin/gates/guards/$1" t0 t1 out key rc=0
  t0="$(date +%s%N)"
  if [ ! -r "$s" ]; then
    printf 'MISSING\t0\t%s\n' "bin/gates/guards/$w — a ward named in the list does not exist" >"$RESULTS/$w"
    return 0
  fi
  key=""
  if [ "$CACHE_OK" -eq 1 ] && grep -q '^# cache: tree$' "$s" 2>/dev/null; then
    key="$(cache_key "$w")"
    if cache_read "$w" "$key"; then
      printf 'CACHED\t0\t%s\n' "unchanged content — the same verdict was already proved" >"$RESULTS/$w"
      return 0
    fi
  fi
  # The scope travels in the ENVIRONMENT, and only a SCOPED ward is handed the paths as
  # arguments — a ward that does not understand them must never be fed them.
  YMIR_GUARD_SCOPE="$CHANGED_LIST"; export YMIR_GUARD_SCOPE
  YMIR_GUARD_SCOPE_COUNT="$SCOPE_COUNT"; export YMIR_GUARD_SCOPE_COUNT
  if is_scoped "$w" && [ "$SCOPE_COUNT" -gt 0 ]; then
    local -a files=()
    mapfile -t files <"$CHANGED_LIST"
    out="$(bash "$s" check "${files[@]}" 2>&1)" || rc=$?
  else
    out="$(bash "$s" check 2>&1)" || rc=$?
  fi
  t1="$(date +%s%N)"
  local ms=$(( (t1 - t0) / 1000000 ))
  if [ "$rc" -eq 0 ]; then
    printf 'PASS\t%s\t\n' "$ms" >"$RESULTS/$w"
    [ -n "$key" ] && cache_write "$w" "$key"
  else
    # The ward's own last line names the fault and its remedy; carry it up rather than
    # swallowing it, because a gate that does not say why is an obstacle. The pattern is the
    # ward SUFFIX, not two named wards: it read `^(defaults|runtime)-guard:` until 2026-11-04,
    # so every other ward's reason was thrown away and the FAIL row printed an empty finding.
    local why; why="$(printf '%s' "$out" | grep -E '^[[:alnum:]_-]+-guard|^[[:alnum:]_-]+-[a-z]+:' | tail -1 | cut -c1-200)"
    [ -n "$why" ] || why="$(printf '%s' "$out" | grep -vE '^[[:space:]]*$' | tail -1 | cut -c1-200)"
    if inherited "$w" "$out"; then
      printf 'INHERITED\t%s\t%s\n' "$ms" "$why" >"$RESULTS/$w"
    else
      printf 'FAIL\t%s\t%s\n' "$ms" "$why" >"$RESULTS/$w"
    fi
  fi
}

pending=()
for w in "${WARDS[@]}"; do
  if is_pr_only "$w"; then
    printf 'PR\t0\t%s\n' "$(pr_only_reason "$w")" >"$RESULTS/$w"
    continue
  fi
  if [ "$FULL" -eq 0 ] && is_ci_only "$w"; then
    printf 'CI\t0\t%s\n' "$(ci_only_reason "$w")" >"$RESULTS/$w"
    continue
  fi
  pending+=("$w")
done

for w in "${pending[@]}"; do
  if [ "$DEADLINE" -gt 0 ] && [ "$(date +%s)" -ge "$DEADLINE" ]; then
    DEFERRED+=("$w")
    printf 'DEFERRED\t0\t%s\n' "the ${BUDGET}s pre-push budget was spent — CI runs this ward on the PR" >"$RESULTS/$w"
    continue
  fi
  run_ward "$w" &
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do
    sleep 0.05
    if [ "$DEADLINE" -gt 0 ] && [ "$(date +%s)" -ge "$((DEADLINE + 10))" ]; then break; fi
  done
done
wait

# ── one TOON table, sorted by status (plan 243 §3, part C) ───────────────────
order() { case "$1" in FAIL) printf '0';; MISSING) printf '1';; DEFERRED) printf '2';; INHERITED) printf '3';; PASS) printf '4';; CACHED) printf '5';; CI) printf '6';; PR) printf '7';; *) printf '8';; esac; }
rows=""
for w in "${WARDS[@]}"; do
  [ -r "$RESULTS/$w" ] || continue
  st="$(cut -f1 "$RESULTS/$w")"; ms="$(cut -f2 "$RESULTS/$w")"; fd="$(cut -f3- "$RESULTS/$w")"
  rows+="$(order "$st")"$'\t'"$w"$'\t'"$st"$'\t'"${ms:-0}"$'\t'"$fd"$'\n'
done
printf 'guards[%s]{ward,status,ms,finding}:\n' "${#WARDS[@]}"
printf '%s' "$rows" | sort -t$'\t' -k1,1n -k4,4nr -k2,2 | while IFS=$'\t' read -r _ w st ms fd; do
  [ -n "$w" ] || continue
  printf '  "%s","%s","%s","%s"\n' "$w" "$st" "$ms" "${fd%$'\n'}"
done

[ "$PROFILE" -eq 1 ] && {
  printf 'profile[%s]{ward,ms,budget}:\n' "${#WARDS[@]}"
  printf '%s' "$rows" | sort -t$'\t' -k4,4nr | while IFS=$'\t' read -r _ w st ms fd; do
    [ -n "$w" ] || continue
    over=""; [ "${ms:-0}" -gt 10000 ] && over="over the 10s line — candidate for CI-only"
    printf '  "%s","%s","%s"\n' "$w" "$ms" "$over"
  done
}

END_ALL="$(date +%s%N)"
TOTAL_MS=$(( (END_ALL - START_ALL) / 1000000 ))
count_status() { local want="$1" n=0 w; for w in "${WARDS[@]}"; do [ -r "$RESULTS/$w" ] || continue; [ "$(cut -f1 "$RESULTS/$w")" = "$want" ] && n=$((n+1)); done; printf '%s' "$n"; }
n_fail=$(count_status FAIL); n_missing=$(count_status MISSING); n_inh=$(count_status INHERITED)
n_def=$(count_status DEFERRED); n_ci=$(count_status CI); n_cache=$(count_status CACHED); n_pr=$(count_status PR)

print_scope() {
  if [ "$FULL" -eq 1 ]; then
    printf 'guards: --full — every ward, the whole tree (the CI posture)\n'
  elif [ -n "$SCOPE_NOTE" ]; then
    printf 'guards: %s\n' "$SCOPE_NOTE"
  else
    printf 'guards: %s changed path(s) judged; %s CI-only ward(s) and %s PR-only ward(s) judged by CI, not here\n' "$SCOPE_COUNT" "$n_ci" "$n_pr"
  fi
  printf 'guards: %s ms total (budget %s s, %s ward(s) at a time)%s\n' "$TOTAL_MS" \
    "$( [ "$BUDGET" -eq 0 ] && printf 'none' || printf '%s' "$BUDGET" )" "$JOBS" \
    "$( [ "$CACHE_OK" -eq 1 ] && printf ', cache on' || printf ', cache off' )"
}
print_scope

if [ "$n_fail" -ne 0 ] || [ "$n_missing" -ne 0 ]; then
  printf 'guards: %s ward(s) failed on THIS push — see the FAIL row above\n' "$n_fail" >&2
  printf 'help: run the failing ward directly; its message names the remedy\n' >&2
  rm -rf "$RESULTS"; rm -f "$CHANGED_LIST"
  exit 1
fi
if [ "$n_inh" -ne 0 ]; then
  printf 'guards: %s finding(s) INHERITED — they name files this push did not touch, so they belong to main, not to you\n' "$n_inh" >&2
  printf 'guards: the push proceeds; CI refuses them on the PR, and the sweep opens one issue naming the ward and the breaking commit\n' >&2
fi
if [ "$n_def" -ne 0 ]; then
  printf 'guards: %s ward(s) DEFERRED to CI — the pre-push budget ran out before they finished\n' "$n_def" >&2
fi
rm -rf "$RESULTS"; rm -f "$CHANGED_LIST"
exit 0
