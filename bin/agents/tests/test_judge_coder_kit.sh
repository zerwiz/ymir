#!/usr/bin/env bash
# test_judge_coder_kit.sh — what the judge and the coder are handed, and how their models are chosen (2026-11-21).
#
# Proves, against a PLANTED home (no real registry, plan or secret is read):
#   1. the role list: the first servable choice wins, a skipped one is named, an unservable list is a refusal,
#      an explicit --harness/--model wins, a per-machine overlay replaces a role;
#   2. yolo: the house default (coder on), the role row, the flag, and the posture line the spawn prints;
#   3. the coder's brief: the stale "Glitnir human gate owns the merge" rule is gone, the judge-merges rule, the
#      Read first section, the talk door and the stall watch are in;
#   4. Read first: where.sh's rows become a list of paths; the judge's list adds the compliance gate;
#   5. the plans a PR claims resolve to plan FILES, and an unknown plan is named, not dropped;
#   6. the figure card opens the prompt on every role.
set -u
here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
root="$(dirname "$(dirname "$(dirname "$here")")")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
has() { printf '%s' "$1" | grep -qF -- "$2"; }
echo "test_judge_coder_kit"

roles="$tmp/roles"; mkdir -p "$roles"
cat >"$roles/agents.yaml" <<'YAML'
roles:
  judge: [pi:zz-no-such/model, claude:opus]
  coder: {choose: ["pi:zz-no-such/model", "claude:sonnet"], yolo: on}
  scout: ["pi:zz-no-such/model"]
YAML
rm_() { YMIR_ROLES_DIR="$roles" YMIR_HOST_OVERRIDE="${HOSTX:-testbox}" bash "$root/bin/model/role-model.sh" "$@"; }

# ---- 1 · the role list -------------------------------------------------------------------------
out="$(rm_ coder 2>"$tmp/err")"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "$(printf 'claude\tsonnet')" ] && ok "the first servable choice wins (claude:sonnet)" || bad "first servable choice: rc=$rc out=$out"
has "$(cat "$tmp/err")" "skipped pi:zz-no-such/model" && ok "the skipped choice is named on stderr" || bad "skipped choice not named"
rm_ scout >/dev/null 2>"$tmp/err"; rc=$?
[ "$rc" -eq 3 ] && ok "a list with nothing servable is a refusal (exit 3)" || bad "unservable list exit $rc"
rm_ scout --harness pi --model x/y 2>/dev/null | grep -q "^pi.x/y" && ok "an explicit --harness/--model wins over the list" || bad "explicit pair did not win"
rm_ helm >/dev/null 2>&1; [ "$?" -eq 3 ] && ok "an undeclared role is refused by name" || bad "undeclared role not refused"
printf 'roles:\n  coder: [claude:opus]\n' >"$roles/agents.testbox.yaml"
out="$(rm_ coder 2>/dev/null)"; [ "$out" = "$(printf 'claude\topus')" ] && ok "the machine overlay replaces a role's list" || bad "overlay: $out"
out="$(rm_ judge 2>/dev/null)"; [ "$out" = "$(printf 'claude\topus')" ] && ok "a role the overlay does not name keeps the fleet's list" || bad "judge under overlay: $out"
rm -f "$roles/agents.testbox.yaml"

# ---- 2 · yolo ---------------------------------------------------------------------------------
out="$(rm_ yolo coder)"; [ "${out%%$'\t'*}" = on ] && ok "yolo: the coder row says on" || bad "coder yolo: $out"
out="$(rm_ yolo judge)"; [ "${out%%$'\t'*}" = off ] && ok "yolo: the judge is off by the house default" || bad "judge yolo: $out"
out="$(rm_ yolo coder off)"; [ "${out%%$'\t'*}" = off ] && ok "yolo: the flag beats the role's row" || bad "flag: $out"
has "$(rm_ posture coder claude on)" "bypassPermissions" && ok "posture: claude on says bypassPermissions" || bad "posture on"
has "$(rm_ posture coder claude off)" "dontAsk" && ok "posture: claude off says dontAsk" || bad "posture off"

# ---- 3 · the coder's brief ----------------------------------------------------------------------
data="$tmp/data"; state="$tmp/state"; mkdir -p "$data" "$state"
BROKK_DATA_OVERRIDE="$data" BROKK_STATE_OVERRIDE="$state" bash "$root/bin/agents/erindi-brief.sh" kit-t ymir --mode direct-PR --paths "src/ymir_runtime/seat.py" >/dev/null 2>&1
b="$(cat "$data/kit-t/brief.md" 2>/dev/null)"
has "$b" "Glitnir human gate owns the merge" && bad "the stale merge rule is still in the coder's brief" || ok "the stale 'human gate owns the merge' rule is gone"
has "$b" "The judge reviews every PR" && has "$b" "NEEDS-REWORK comes back to this seat" && ok "rule 1 says the judge merges and a rework comes back" || bad "rule 1 not rewritten"
has "$b" "# Read first" && has "$b" "brokk-distro-runtime" && ok "the brief carries a Read first section from where.sh" || bad "no Read first"
has "$b" "bin/agents/tell.sh" && ok "rule 9 names the one door for talking to agents" || bad "no tell door"
has "$b" "STALL CHECK" && ok "rule 10 names the stall watch" || bad "no stall rule"
has "$b" "30 minutes" && has "$b" "ssh" && ok "the command limit and the ssh rule are still there" || bad "limit/ssh rule lost"
has "$b" "The judge reviews it and merges on approval" && ok "the done gate no longer routes to a human seal" || bad "stale done line"

# ---- 4 · Read first --------------------------------------------------------------------------
out="$(bash "$root/bin/agents/read-first.sh" --judge src/ymir_runtime/seat.py)"
has "$out" "brokk-distro-runtime" && has "$out" "compliance-check.sh" && ok "the judge's list names the book and the compliance gate" || bad "judge read-first: $out"
out="$(bash "$root/bin/agents/read-first.sh" docs/nowhere/at-all.md)"; [ -z "$out" ] && ok "an unmapped path alone prints nothing for a coder" || bad "unmapped printed: $out"

# ---- 5 · the plans a PR claims ----------------------------------------------------------------
ledger="$tmp/ledger"; mkdir -p "$ledger"; : >"$ledger/275-the-forge.md"; : >"$ledger/339-the-trouble.md"
printf 'Closes the work of plans 275 and 339 and plan 4040.\n' >"$tmp/pr.txt"
out="$(python3 "$root/bin/agents/plan-claims.py" --ledgers "$ledger" "$tmp/pr.txt")"
has "$out" "$ledger/275-the-forge.md" && has "$out" "$ledger/339-the-trouble.md" && ok "plan numbers resolve to plan files" || bad "plan files: $out"
has "$out" "unresolved: plan 4040" && ok "a plan with no file is named, never dropped" || bad "unresolved not named"
out="$(printf 'nothing claimed here\n' | python3 "$root/bin/agents/plan-claims.py" --stdin --ledgers "$ledger")"
[ -z "$out" ] && ok "no claim, no plan" || bad "phantom plan: $out"

# ---- 6 · the figure card opens the prompt on every role ----------------------------------------
for r in judge coder scout helm; do
  c="$(bash "$root/bin/seat/figure-card.sh" "$r")"
  case "$c" in "# Your card — "*) ok "the $r seat opens with its figure's card" ;; *) bad "no card for $r" ;; esac
done

# ---- 7 · the spawn prints which posture took effect --------------------------------------------
home="$tmp/home"; mkdir -p "$home/hodd/data/kit-t" "$home/hodd/identity" "$home/state" "$home/config"
cp "$data/kit-t/brief.md" "$home/hodd/data/kit-t/brief.md"
cp "$roles/agents.yaml" "$home/config/agents.yaml"
out="$(YMIR_HOME="$home" YMIR_ENGINE=off timeout 120 bash "$root/bin/agents/einherjar-spawn.sh" kit-t "$root" --mode direct-PR --dry-run 2>&1)"
has "$out" "posture kit-t role=coder harness=claude model=sonnet: yolo on" && has "$out" "bypassPermissions" && ok "the spawn prints the posture that took effect (role list + yolo)" || bad "no posture line: $(printf '%s' "$out" | grep posture)"
out="$(YMIR_HOME="$home" YMIR_ENGINE=off timeout 120 bash "$root/bin/agents/einherjar-spawn.sh" kit-t "$root" --mode direct-PR --yolo off --dry-run 2>&1)"
has "$out" "yolo off" && has "$out" "dontAsk" && ok "--yolo off beats the role's row and says dontAsk" || bad "yolo off not honoured"

printf 'test_judge_coder_kit: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
