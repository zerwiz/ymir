#!/usr/bin/env bash
# ci-verify.sh — what CI must prove, in one command, for BOTH hosts.
#
# GitHub Actions and Forgejo Actions are two doors to the same room, so neither holds a
# copy of the checks: both call THIS. A workflow that re-listed the steps would be a second
# place for them to drift, which is the failure this whole repository is being taught to stop.
#
# Usage:
#   ci-verify.sh            # run every gate CI owes
#   ci-verify.sh --fast     # skip the heavy one (the real npm install)
#
# Exit: 0 everything proved · 1 a gate failed · 2 usage.
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

FAST=0
case "${1-}" in
  -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --fast)    FAST=1 ;;
  "")        ;;
  *)         printf 'error: unknown flag %s\nhelp: ci-verify.sh [--fast]\n' "${1-}" >&2; exit 2 ;;
esac

fail=0
printf 'ci_verify[4]{gate,status,detail}:\n'

# THE VERDICT, IN A FILE (plan 243 §3, part E). When CI is red on main, the sweep must be able
# to name the ward and the commit that broke it without re-running a five-minute suite over the
# failure. So every failing gate is written here as `gate<TAB>what`, and the ward gate's own
# table is kept beside it (`<verdict>.wards`) — bin/gates/main-red.sh reads the log (one door for a red main, plan 243 part E).
VERDICT="${YMIR_CI_VERDICT:-${TMPDIR:-/tmp}/ymir-ci-verdict.txt}"
: >"$VERDICT" 2>/dev/null || VERDICT=/dev/null

gate() {  # <name> <description> <command...>
  local name="$1" what="$2"; shift 2
  local out; out="$( "$@" 2>&1 )" && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '  "%s","PASS","%s"\n' "$name" "$what"
  else
    printf '%s\t%s\n' "$name" "$what" >>"$VERDICT" 2>/dev/null || true
    printf '  "%s","FAIL","%s"\n' "$name" "$what"
    # The failing gate's own tail — the single-line swallow hid WHICH check
    # died inside (e.g. pr-pretest's hull/sandbox/app-boot rows). Print the
    # last 12 lines so CI tells us the actual failing step.
    printf '%s\n' "$out" | grep -vE '^[[:space:]]*$' | tail -12 | sed 's/^/    /'
    fail=1
  fi
}

# SEAT THE MERGE DRIVER FIRST. `features-guard` requires `merge.regenerate.driver` to exist in the
# clone's git config — a fresh checkout (every CI run) has it unset, so the ward failed on correct code
# with "the merge driver is not seated", which is the same false red this house keeps paying for.
# The install seats it on a real seat; CI seats it here, once, before the wards.
if [ -x "$ROOT/bin/records/weave-features.sh" ]; then
  "$ROOT/bin/records/weave-features.sh" --install >/dev/null 2>&1 || \
    printf '  "%s","NOTE","%s"\n' weave-driver "the merge driver could not be seated in this clone"
fi
# THE WHOLE TREE, EVERY WARD (plan 243 §3, part E). `--full` is the CI posture: no diff scope,
# no budget, no cache, and the wards the pre-push moved here (inventory, registers, docs-claims,
# language, dead-code) all run. This is why a local skip is still safe — nothing is judged only
# by a hook a pusher may not have installed.
ward_check() { bash "$ROOT/bin/gates/guards.sh" --full 2>&1 | tee "$VERDICT.wards"; return "${PIPESTATUS[0]}"; }
gate ward        "every tree ward, the whole tree (guards.sh --full)" ward_check
gate dead-code-paths "the dead-code ward judges normal and Yggdrasil checkouts" \
     python3 "$ROOT/tests/test_dead_code_worktrees.py"
# 2026-11-06 — the sweep judged a LIVE errand dead 3m59s after launch, because herdr
# reported its agent `done` and `done` means idle, not finished. The grace is what makes
# a quiet pane evidence of quiet rather than evidence of death; this is the proof it bites
# both ways (SETTLING inside the window, DEAD past it).
gate liveness-grace "the sweep never calls a live seat dead inside the settling grace" \
     bash "$ROOT/tests/test_eindri_liveness_grace.sh"
# The "everything up" wards: worker seats are never the helm, the rendered config resolves the home
# (and refuses when it cannot), the one task-board writer, the acclaim PR guard (scout exempt).
gate everything-up "seat wards: stop hook, hoard-resolved config, one-writer todos, acclaim PR guard" \
     bash "$ROOT/bin/seat/tests/test_everything_up.sh"
# Plan 275 — the update keeps every machine whole: the launchers start from the pin, the pin door refuses a dirty
# pin and rolls back an update that does not settle, Rödd's face follows its patches, and the hall keeps one home.
gate launcher-guard "the app launchers run in place on the pin and send a worktree to main's copy" \
     bash "$ROOT/bin/desktop/tests/test_launcher_worktree_guard.sh"
gate pin-door-stable "the pin door refuses a dirty pin, rolls back an unsettled update and records last-good" \
     bash "$ROOT/bin/engine/tests/test_runtime_deploy_stable.sh"
# Plan 278 — an update finishes the installs: Eir mends by risk class from one register, Gróa's last line
# tells the truth, and a unit still running a retired value is found and re-seated.
gate eir-register "Eir reads config/surfaces.yaml, mends only safe surfaces unattended, and never leaves a broken row without a reason" \
     bash "$ROOT/bin/agents/tests/test_eir_register.sh"
gate groa-verdict "Gróa's closing line says whole or names every owed surface, and a stopped step fails it" \
     bash "$ROOT/bin/agents/tests/test_groa_verdict.sh"
gate unit-drift "an installed unit on a retired value is found and re-seated; a seat's own choice is not drift" \
     bash "$ROOT/bin/engine/tests/test_units_drift.sh"
gate rodd-face-follows "Rödd's face is re-dressed when its patches change" \
     bash "$ROOT/apps/rodd/smoke/test_face_follows_patches.sh"
gate hall-data-home "two checkouts of the hall share one data home and nothing is lost" \
     bash "$ROOT/apps/bilskirnir/tests/data-home.sh"
gate hall-keeps-changes "the first agent keeps the user's soul lines and config additions across setup" \
     bash "$ROOT/apps/bilskirnir/tests/keeps-user-changes.sh"
# RULES/04 — the public tree carries TEMPLATES and LOGIC. The ward is in the list above; this is
# the proof that it BITES (a ward never seen to refuse is decoration, and this one wore that coat).
gate public-data "RULES/04 — a secret, a name, a topology, a mailbox or a machine named as a host is refused, and the ward is proved to refuse" \
     bash "$ROOT/bin/gates/checks/public-data-ward.test.sh"
# Plan 278: the Nornir board takes its server seats from the fleet registry, never names in the code. bun is the
# server's runtime, but the test is written on node:test so CI's pinned Node runs it.
gate cron-seats "the Hlidskjalf cron board reads its server seats from the fleet registry" \
     node --test "$ROOT/apps/hlidskjalf/server/server-seats.test.ts"

# The mocks gate was an inline pipeline with no test, so every exclusion it grew arrived as a false red on
# legitimate code and was judged by eye. The scan is a file now, and this proves it bites AND stays narrow.
gate mocks-vocabulary "the mocks scan catches a half-built door and excuses only vocabulary" \
     bash "$ROOT/.agents/tests/mocks-scan.test.sh"

# A RED MAIN MUST SHOUT (plan 243 part E, 2026-11-11). The gate on main was red for four
# consecutive commits and nothing in the house said so — every hand pushed into it and every
# push failed for drift it had not caused. `bin/gates/main-red.sh` is the alarm; this is the
# proof that it BITES (a finding names the gate and quotes the ward) and that it stays QUIET
# where it must (a green log files nothing, no token calls no API, and only a main push may
# open the issue).
gate main-red "the alarm for a red main names the ward and never fires for a pull request" \
     bash "$ROOT/bin/gates/tests/test_main_red.sh"

# PLAN 262 — an OpenCode worker actually starts. The interactive TUI refuses --model (OpenCode v2),
# four doors each built their own shape and three drifted. One launcher, four callers, and this is
# the parity test plus the version guard that keeps it from drifting again.
gate opencode-launcher "every door seats OpenCode with the launcher's one shape; the version guard bites" \
     bash "$ROOT/bin/gates/tests/test_opencode_launcher.sh"

# PLAN 293 part 7 — a worker cut from another unmerged branch records that branch in its packet, and
# the gather merges the base FIRST. Gathered in the wrong order the dependent lands before its base.
gate gather-orders-by-base "the gather merges a packet's base branch before the branch cut from it" \
     bash "$ROOT/bin/gates/tests/test_gather_orders_by_base.sh"

# Rule 11 — a tracked file is MOVED, never deleted. RULES/11 says the ward runs here; until
# 2026-11-03 nothing in this file called it, so a deletion passed CI unseen. The range is the
# PR's base when there is one, and an honest SKIP (not a green) when this checkout has no base.
nodelete_base() {
  local b=""
  if [ -n "${GITHUB_BASE_REF:-}" ] && git rev-parse -q --verify "origin/${GITHUB_BASE_REF}" >/dev/null 2>&1; then
    b="origin/${GITHUB_BASE_REF}"
  elif git rev-parse -q --verify origin/main >/dev/null 2>&1; then
    b="origin/main"
  fi
  [ -n "$b" ] || return 1
  printf '%s' "$b"
}
if nd_base="$(nodelete_base)"; then
  gate no-delete "Rule 11 — a tracked file is moved, never deleted (against $nd_base)" \
       bash "$ROOT/bin/no-delete-guard.sh" --base "$nd_base"
  # `--check`, not `--base`: on a pull request the checkout is the host's merge commit, and the
  # ward's merge-aware path (HEAD^1..HEAD^2) is the only range that is the contributor's own.
  gate identity  "Rule 04/39 — a commit publishes an account, never a private mailbox" \
       bash "$ROOT/bin/gates/guards/identity-guard.sh" --check
else
  printf '  "%s","SKIP","%s"\n' "no-delete" "no base ref in this checkout — judged by the pre-push hook and on a PR"
fi
gate compliance  "the 15 governance gates"              bash "$ROOT/.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh"
gate contracts   "the typed surfaces (one contract, two consumers)" bash "$ROOT/bin/gates/checks/contracts-check.sh"
gate queue       "the derived work queue is current"              bash "$ROOT/bin/gates/queue.sh" --check
gate plan-ledger  "every plan carries the contract (his words, a measure, proven phases, a refusal, questions, a number, a row with a status)" \
               bash "$ROOT/bin/gates/plan-audit.sh" --check
gate capability "the capability register is current"           bash "$ROOT/bin/gates/capabilities.sh" --check
gate home-index "the home's shelves are navigable"             bash "$ROOT/bin/gates/checks/home-index-check.sh"
gate triggers    "a smithy starts by a person, the clock or an event — and nothing arms itself" \
               bash "$ROOT/bin/time/tests/test_event_trigger.sh"
gate voice-arm   "Rödd knocks on the arm, and refuses when nobody is holding it (plan 223)" \
               bash "$ROOT/bin/voice/tests/test_rodd_arm.sh"
# PLAN 293 part 3 — the digest SEES what never landed: a pushed worker branch with no PR, and a
# commit on no remote. A warning nobody runs is decoration, so the door is proved on a planted
# repository, including the offline path (a branch is never called PR-less on a failed question).
gate landing     "Sága names the branches pushed with no PR and the commits on no remote (plan 293)" \
               bash "$ROOT/bin/time/tests/test_saga_land_warnings.sh"
# PLAN 293 part 4 — the LAST errand of a batch calls the gather, once, naming the ids and the exact
# command. Membership is the meta's own `mode=batch` + `wave`, never a second registry.
gate gather-notice "the last errand of a batch prompts the gather, once, with the command (plan 293)" \
               bash "$ROOT/bin/forge/tests/test_gather_notice.sh"
gate usage      "no door became unused since the baseline"    bash "$ROOT/bin/gates/checks/usage-ratchet.sh"
gate portability "GNU-only callers may fall, never rise (RULES/05)"    bash "$ROOT/bin/gates/checks/portability-ratchet.sh" check
gate inventory  "the bin/backend index is current"            bash "$ROOT/bin/gates/inventory.sh" --check
# plan 175 §3 — CI keeps the LAST word on the weaver. The pre-commit hook is CONVENIENCE (it can be
# bypassed with --no-verify) and the ward runs where the tree is pushed; this row judges the merge
# the host builds, so a stale index is refused even when no hook on any machine ever fired.
gate weave      "every index names every rule, plan and feature page (plan 175)" \
               bash "$ROOT/bin/records/weave.sh" --check
gate workflows  "every Actions workflow parses"               bash "$ROOT/bin/gates/checks/workflow-check.sh" --quiet
gate units      "systemd reads every key in every unit template" bash "$ROOT/bin/gates/checks/unit-template-check.sh" --quiet
gate ext-api    "extensions speak Pi's real tool API"          bash "$ROOT/bin/gates/checks/extension-api-check.sh" --quiet
gate ext-smoke  "every Ymir tool ANSWERS when called like Pi calls it" \
               node --experimental-strip-types "$ROOT/tools/extension-smoke.mjs"
codex_checks() {
  local door
  for door in bin/engine/ymir-install.sh bin/agents/groa-update.sh bin/bridge/ymir-plan.sh; do
    bash -n "$ROOT/$door" || return 1
  done
  node --test "$ROOT/tests/test_codex_plugin.mjs" "$ROOT/tests/test_codex_install.mjs" "$ROOT/tests/test_codex_wsl_well.mjs"
}
gate codex-plugin "the Codex tool catalog, shell syntax, install and refresh contract" codex_checks
# The publish pretest is no longer a per-push gate (the Allfather, 2026-11-04: *"stop testing the npm
# installation on every push"*). It packs the real tarball, installs it in a sandbox and boots the apps —
# minutes of work that proved NOTHING about a change that cannot affect the artifact, and its cost made
# every push slow enough to invite the override that this house has learned to distrust.
# It has its own door now: .github/workflows/npm-pretest.yml, run by hand or when the artifact's own inputs
# change (package.json · the app build · the hull), and `bin/forge/npm/pr-pretest.sh` locally before a
# release. Set YMIR_PRETEST_ON_PUSH=1 to run it here as before.
if [ "${YMIR_PRETEST_ON_PUSH:-0}" = 1 ]; then
  gate pr-pretest  "a REAL npm install of the publish artifact" bash "$ROOT/bin/forge/npm/npm-pretest.sh local"
else
  printf '  "%s","SKIP","%s"\n' pr-pretest "the publish artifact is proved by .github/workflows/npm-pretest.yml (set YMIR_PRETEST_ON_PUSH=1 to run it here)"
fi

if [ "$fail" -eq 0 ]; then
  exit 0
fi
printf 'ci-verify: a gate failed — see the FAIL row above\nhelp: run the failing gate directly\n' >&2
exit 1
