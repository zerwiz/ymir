#!/usr/bin/env bash
# compliance-check.sh — Galdr/Tyr compliance gates for the Ymir runtime + skills.
#
# Runs the runtime acceptance gates as one command, TOON output on stdout,
# structured errors, no prompts, idempotent, --version fast path.
#
# Usage:
#   compliance-check.sh [--json] [--quiet]
#   compliance-check.sh --version | -v
#
# Gates:
#   toon      TOON blocks in galdr SKILL.md + assets + tyr SKILL.md + AGENTS.md
#   naming    no imported terms (captain/crewmate; firstmate only in provenance)
#   mocks     no mock/stub/placeholder in the shipped runtime (bin/*.sh)
#   syntax    bash -n on bin/*.sh; node --check on plugins
#   json      every runtime JSON parses
#   sync      galdr-cli/assets mirrors tyr-check/assets
#
# Exit: 0 = all pass, 1 = one or more FAIL, 2 = usage error.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
GALDR="$ROOT/.agents/skills/galdr-cli"
TYR="$ROOT/.agents/skills/tyr-check"
TOON_CHECK="$SCRIPT_DIR/toon-check.py"

for a in "$@"; do
  case "$a" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

QUIET=0
JSON=0
for a in "$@"; do
  [ "$a" = "--quiet" ] && QUIET=1
  [ "$a" = "--json" ] && JSON=1
done

declare -a IDS CHECKS STATUS DETAILS
add() { IDS+=("$1"); CHECKS+=("$2"); STATUS+=("$3"); DETAILS+=("$4"); }

say() { [ "$QUIET" = 1 ] || printf '%s\n' "$1"; }

# --- toon -------------------------------------------------------------------
toon_targets=("$GALDR/SKILL.md")
[ -d "$GALDR/assets" ] && toon_targets+=("$GALDR/assets")
[ -f "$TYR/SKILL.md" ] && toon_targets+=("$TYR/SKILL.md")
[ -f "$ROOT/AGENTS.md" ] && toon_targets+=("$ROOT/AGENTS.md")
if out=$(python3 "$TOON_CHECK" "${toon_targets[@]}" 2>&1); then
  nblocks=$(printf "%s" "$out" | grep -c '^  "' || true)
  add toon "TOON blocks valid" PASS "${nblocks} blocks valid"
else
  add toon "TOON blocks valid" FAIL "$(printf '%s' "$out" | grep -m1 '^error:' || echo 'violations')"
fi

# --- naming -----------------------------------------------------------------
# Scope: the always-loaded contract and the shipped runtime. Law statements that
# name a forbidden term ("never captain", "no imported term") are not violations.
naming_fail=""
for f in "$ROOT/AGENTS.md" "$ROOT"/bin/*.sh; do
  [ -f "$f" ] || continue
  # The Huginn observer is the read-only bridge to the external distro; it
  # legitimately names that system's tooling and paths.
  [ "${f##*/}" = "nornir-job-observer.sh" ] && continue
  hit=$(grep -nEi 'captain|crewmate' "$f" 2>/dev/null | grep -vEi 'never|imported|\.treehouse' || true)
  [ -n "$hit" ] && naming_fail="$naming_fail ${f##*/}:$(printf '%s' "$hit" | head -n1 | cut -d: -f1)"
done
# Note: the upstream project name is permitted in the assets as provenance
# (paths, env bindings, and the port record); this gate checks the runtime only.
if [ -z "$naming_fail" ]; then
  add naming "no imported terms" PASS "Allfather + Norse names only"
else
  add naming "no imported terms" FAIL "imported term at$naming_fail"
fi

# --- mocks ------------------------------------------------------------------
# A legitimate filename is not a stub: TODO.md appears in an allowlist in
# bin/public-guard.sh, so ignore that filename (not the word) here.
mock_hits=$(grep -rniE '\b(mock|stub|placeholder|todo)\b' "$ROOT/bin" 2>/dev/null | grep -v 'PUBLIC=' || true)
if [ -z "$mock_hits" ]; then
  add mocks "no mocks in shipped runtime" PASS "bin/ clean"
else
  add mocks "no mocks in shipped runtime" FAIL "$(printf '%s' "$mock_hits" | head -n1)"
fi

# --- syntax -----------------------------------------------------------------
syn_fail=""
for f in "$ROOT"/bin/*.sh; do
  [ -e "$f" ] || continue
  bash -n "$f" 2>/dev/null || syn_fail="$syn_fail ${f##*/}"
done
while IFS= read -r f; do
  node --check "$f" 2>/dev/null || syn_fail="$syn_fail $(basename "$f")"
done < <(find "$ROOT/.opencode/plugins" -name '*.js' 2>/dev/null)
if [ -z "$syn_fail" ]; then
  add syntax "shell + plugin syntax" PASS "bash -n + node --check clean"
else
  add syntax "shell + plugin syntax" FAIL "failed:$syn_fail"
fi

# --- json -------------------------------------------------------------------
json_fail=""
while IFS= read -r f; do
  python3 -m json.tool "$f" >/dev/null 2>&1 || json_fail="$json_fail ${f##*/}"
done < <(find "$ROOT/config" "$ROOT/.claude" "$ROOT/.codex" "$ROOT/.cursor" "$ROOT/.agents/skills/galdr-cli/assets/pi-boot" "$ROOT/.agents/sandbox" \
  -maxdepth 1 -name '*.json' 2>/dev/null; [ -f "$ROOT/opencode.json" ] && echo "$ROOT/opencode.json")
if [ -z "$json_fail" ]; then
  add json "runtime JSON parses" PASS "all parse"
else
  add json "runtime JSON parses" FAIL "failed:$json_fail"
fi

# --- sync -------------------------------------------------------------------
if diff -rq "$GALDR/assets" "$TYR/assets" >/dev/null 2>&1; then
  add sync "galdr/tyr assets mirrored" PASS "in sync"
else
  add sync "galdr/tyr assets mirrored" FAIL "drift detected"
fi

# --- surfaces ---------------------------------------------------------------
# Galdr is dual-surface: the agent must resolve to the canonical skill.
if [ -L "$ROOT/.agents/agents/galdr.md" ] && [ "$(readlink "$ROOT/.agents/agents/galdr.md")" = "../skills/galdr-cli/SKILL.md" ]; then
  add surfaces "Galdr agent+skill dual-surface" PASS "agent symlinks the skill"
elif diff -q "$ROOT/.agents/agents/galdr.md" "$GALDR/SKILL.md" >/dev/null 2>&1; then
  add surfaces "Galdr agent+skill dual-surface" PASS "agent mirrors the skill"
else
  add surfaces "Galdr agent+skill dual-surface" FAIL "agent and skill differ"
fi

# --- assets (governed paths) -------------------------------------------------
# A governed file changed in the working tree must have its owning asset changed
# in the same change, or the runtime has drifted from its documentation.
asset_for() {
  case "$1" in
    *bin/ymir-install.sh)                      printf '%s' "$GALDR/assets/installation.md" ;;
    *apps/hlidskjalf/*)                        printf '%s' "$GALDR/assets/hlidskjalf-ui.md" ;;
    *bin/mimir*)                               printf '%s' "$GALDR/assets/memory-well.md" ;;
    *bin/gleipnir-lock-lib.sh|*bin/saga-session-start.sh|*state/.lock) printf '%s' "$GALDR/assets/brokk-distro-runtime.md" ;;
    *bin/nornir-*|*config/cron.yaml)           printf '%s' "$GALDR/assets/nornir-jobs.md" ;;
    *bin/valknut-load.sh|*/.pi/*|*/.opencode/*) printf '%s' "$GALDR/assets/harness-integration/README.md" ;;
    *bin/smidja*|*.agents/skills/smidja/*)     printf '%s' "$GALDR/assets/smidja.md" ;;
    *)                                         printf '' ;;
  esac
}
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  changed="$(git -C "$ROOT" diff --name-only HEAD 2>/dev/null || true)"
  stale=""
  for f in $changed; do
    a="$(asset_for "/$f")"
    [ -n "$a" ] || continue
    # Stale only when the asset itself did NOT also change.
    printf '%s\n' "$changed" | grep -qxF "${a#"$ROOT"/}" && continue
    stale="$stale ${f##*/}"
  done
  if [ -z "$stale" ]; then
    add assets "governed assets current" PASS "no stale governed paths"
  else
    add assets "governed assets current" FAIL "stale (asset not updated):$stale"
  fi
else
  add assets "governed assets current" SKIP "not a git work tree"
fi

# --- duplicates -------------------------------------------------------------
if [ -d "$ROOT/assets/skills/assets" ]; then
  add duplicates "no duplicate asset trees" FAIL "assets/skills/assets exists"
else
  add duplicates "no duplicate asset trees" PASS "single canonical tree"
fi

# --- output -----------------------------------------------------------------
if [ "$JSON" = 1 ]; then
  printf '{\n  "checks": [\n'
  first=1
  for i in "${!IDS[@]}"; do
    [ $first = 0 ] && printf ',\n'
    first=0
    printf '    {"id":"%s","check":"%s","status":"%s","detail":"%s"}' \
      "${IDS[$i]}" "${CHECKS[$i]}" "${STATUS[$i]}" "${DETAILS[$i]}"
  done
  printf '\n  ]\n}\n'
else
  say "checks[${#IDS[@]}]{id,check,status,detail}:"
  for i in "${!IDS[@]}"; do
    say "  \"${IDS[$i]}\",\"${CHECKS[$i]}\",\"${STATUS[$i]}\",\"${DETAILS[$i]}\""
  done
fi

fails=0
for s in "${STATUS[@]}"; do [ "$s" = FAIL ] && fails=$((fails + 1)); done
if [ "$fails" -gt 0 ]; then
  if [ "$JSON" = 1 ] || [ "$QUIET" = 1 ]; then
    printf 'error: %s gate(s) failed\n' "$fails" >&2
    printf 'help: fix the FAIL rows; see assets/runtime-compliance.md\n' >&2
  else
    printf '\nerror: %s gate(s) failed\n' "$fails"
    printf 'help: fix the FAIL rows above; see assets/runtime-compliance.md\n'
  fi
  exit 1
fi
exit 0
