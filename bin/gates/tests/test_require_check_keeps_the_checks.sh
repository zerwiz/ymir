#!/usr/bin/env bash
# test_require_check_keeps_the_checks.sh — the door that writes main's protection must not lose it.
#
# WHY (the security review, 2026-11-12 → item 1; measured 2026-11-16): `bin/gates/require-check.sh`
# defaulted its check name to `gates` and PATCHed the required set with exactly that one context.
# main's required context is `whole-tree` — the job in .github/workflows/ymir-gates.yml — and there
# is no `gates` job at all. So `--apply` would have replaced the only check guarding main with a name
# GitHub has never seen; a required check that does not exist is read as satisfied, which is a hole
# wearing a green tick. A door may add a check; it may not take one away by accident.
#
# The claims this test holds:
#   1. the door's default check is the job name the workflow calls "THE REQUIRED CHECK";
#   2. a required context that is already set survives `--apply` (the union, never a replace);
#   3. "require branches to be up to date" is NOT flipped by a plain `--apply` — it was turned off
#      on 2026-11-15 on purpose (plan 295 §S2) and re-arming it would restore the starvation;
#   4. `--strict on` does set it, so the decision stays available to the operator;
#   5. unreadable protection exits 1 and names the operator's hand, never a silent green.
#
# Usage: test_require_check_keeps_the_checks.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/gates/require-check.sh"
WORKFLOW="$ROOT/.github/workflows/ymir-gates.yml"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

# ── a fake `gh`, so the door is judged on its own behaviour, not on the network ──
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'FAKE'
#!/usr/bin/env bash
# FAKE gh — answers the two reads the door makes, and records every write.
if [ "${1-}" = api ]; then
  shift
  patch=0; args=()
  while [ $# -gt 0 ]; do
    case "$1" in -X) patch=1; shift 2; continue ;; esac
    args+=("$1"); shift
  done
  path="${args[0]-}"
  case "$patch:$path" in
    1:*protection/required_status_checks)
      printf '%s\n' "${args[*]}" >> "$FAKE_GH_WRITES"
      exit "${FAKE_GH_WRITE_RC:-0}" ;;
    0:*branches/main/protection)
      [ -n "${FAKE_GH_PROTECTION:-}" ] || exit 1
      cat "$FAKE_GH_PROTECTION"; exit 0 ;;
    0:*rulesets) cat "${FAKE_GH_RULESETS:-/dev/null}"; exit 0 ;;
  esac
fi
exit 1
FAKE
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"
export FAKE_GH_WRITES="$T/writes.log"
: > "$FAKE_GH_WRITES"

# one protection document, the shape GitHub returns for main on 2026-11-16
protection() {  # <contexts-csv> <strict> <reviews> <admins>
  python3 - "$@" > "$T/prot.json" <<'PY'
import json, sys
ctx = [c for c in sys.argv[1].split(",") if c]
print(json.dumps({
  "required_status_checks": {"strict": sys.argv[2] == "true", "contexts": ctx},
  "required_pull_request_reviews": {"required_approving_review_count": int(sys.argv[3])},
  "enforce_admins": {"enabled": sys.argv[4] == "true"},
  "allow_force_pushes": {"enabled": False},
  "allow_deletions": {"enabled": False},
}))
PY
  export FAKE_GH_PROTECTION="$T/prot.json"
}
printf '[{"name":"main keeps its history","enforcement":"active"}]' > "$T/rulesets.json"
export FAKE_GH_RULESETS="$T/rulesets.json"

printf 'require-check — the door that writes main protection\n'

# 1 — the default check name is the workflow's own job name
protection "whole-tree" false 0 false
out="$(bash "$DOOR" 2>&1)"; rc=$?
if printf '%s' "$out" | grep -q '"check","whole-tree"'; then
  ok "the default check is whole-tree"
else bad "the default check is whole-tree" "$out"; fi
if grep -qE '^  whole-tree:' "$WORKFLOW"; then
  ok "and whole-tree is a job in .github/workflows/ymir-gates.yml"
else bad "whole-tree is a job in the workflow" "the door's default names no job"; fi
if printf '%s' "$out" | grep -q '"gates"'; then
  bad "the stale 'gates' default is gone" "$(printf '%s' "$out" | grep gates | head -2)"
else ok "the stale 'gates' default is gone"; fi

# reading is read-only
if [ -s "$FAKE_GH_WRITES" ]; then bad "a plain run writes nothing" "$(cat "$FAKE_GH_WRITES")"
else ok "a plain run writes nothing"; fi

# 2 + 3 — apply ADDS, and does not flip up-to-date
: > "$FAKE_GH_WRITES"
out="$(YMIR_GATES_CHECK=new-check bash "$DOOR" --apply 2>&1)"; rc=$?
w="$(cat "$FAKE_GH_WRITES")"
if [ "$rc" -eq 0 ]; then ok "--apply succeeds"; else bad "--apply succeeds" "$out"; fi
if printf '%s' "$w" | grep -q 'contexts\[\]=whole-tree'; then
  ok "the existing required context survives the write (union, not replace)"
else bad "the existing required context survives" "$w"; fi
if printf '%s' "$w" | grep -q 'contexts\[\]=new-check'; then
  ok "the requested check is added"
else bad "the requested check is added" "$w"; fi
if printf '%s' "$w" | grep -q 'strict=false'; then
  ok "up-to-date is left exactly as it was (false)"
else bad "up-to-date is preserved" "$w"; fi

# 4 — asking for it is still possible, and is announced
: > "$FAKE_GH_WRITES"
out="$(bash "$DOOR" --apply --strict on 2>&1)"; w="$(cat "$FAKE_GH_WRITES")"
if printf '%s' "$w" | grep -q 'strict=true'; then ok "--strict on sets up-to-date"
else bad "--strict on sets up-to-date" "$w"; fi
if printf '%s' "$out" | grep -q 'also changes up_to_date'; then
  ok "a change to up-to-date is announced, not slipped in"
else bad "a change to up-to-date is announced" "$out"; fi

# 5 — unreadable protection is an honest refusal, never a green
export FAKE_GH_PROTECTION=""
out="$(bash "$DOOR" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ]; then ok "unreadable protection exits 1"; else bad "unreadable protection exits 1" "rc=$rc"; fi
if printf '%s' "$out" | grep -q "operator's hand on GitHub"; then
  ok "and names whose hand sets it"
else bad "and names whose hand sets it" "$out"; fi

printf 'require-check: %s ok / %s fail\n' "$pass" "$fail"
[ "$fail" = 0 ]
