#!/usr/bin/env bash
# prove-install.sh — THE INSTALL CLAUSE, proven or NAMED as a gap.
#
# The standard says: a clause is proved only by a command, and a clause we cannot
# yet prove is named in public, never dressed up as done. This is the command for
# the install clause. It never re-derives the installer's opinion: it reads the
# plan the installer itself computes (bin/ymir-install.sh --plan --json), so the
# proof cannot drift from the thing it proves.
#
# The clauses:
#   C1 governed-here  this machine is in the governed state — no row of the plan
#                     still asks for action (state DO or WARN)
#   C2 unattended     no step needs a human once the operator has said yes — the
#                     only human states in the plan are CONSENT rows
#   C3 idempotent     the plan is a pure function of state: two runs, one answer
#   C4 fresh-machine  a FRESH machine reaches the governed state unattended
#   C5 removal        removing the runtime leaves the home untouched
#
# C1..C3 run here, now. C4 has no machine to run on yet and C5 has no uninstaller
# at all, so both are NAMED — C4 UNPROVEN, C5 GAP — and neither is ever reported
# as passed. A run that hides a gap is a lie with a green exit code.
#
# Exit: 0 every clause PROVEN (or gaps, unless --strict)
#       1 a clause FAILED or (with --strict) UNPROVEN/GAP
#       2 usage
# Usage: bin/prove-install.sh [--json] [--strict]
set -u

# --- resolve before use: roots come from the libs, never from a literal --------
_yd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _c in "$_yd/hoard-lib.sh" "$(dirname "$_yd")/bin/hoard-lib.sh"; do
  [ -r "$_c" ] && { . "$_c"; break; }
done
unset _yd _c
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAN="$ROOT/bin/ymir-install.sh"

JSON=0; STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json)   JSON=1 ;;
    --strict) STRICT=1 ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown argument %s\nhelp: bin/prove-install.sh [--json] [--strict]\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

[ -x "$PLAN" ] || { printf 'error: the installer is not executable: %s\nhelp: reinstall, or restore bin/ymir-install.sh\n' "$PLAN" >&2; exit 2; }

TMP="$(mktemp -d)" || { printf 'error: cannot make a temp dir\nhelp: check TMPDIR\n' >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

# --- read the installer's own verdict -----------------------------------------
run_plan() {  # <out.json>
  if ! "$PLAN" --plan --json >"$1" 2>"$TMP/plan.err"; then
    printf 'error: the installer could not compute its plan\nhelp: run %s --plan to see why\nreason: %s\n' "$PLAN" "$(tail -1 "$TMP/plan.err")" >&2
    exit 1
  fi
}
run_plan "$TMP/plan1.json"
run_plan "$TMP/plan2.json"

# One reader of the plan. Prints counts on line 1 and the offending rows after,
# one per line as "<STATE> <phase>/<name>/<step>", stable and diffable.
summarize() {  # <plan.json>
  python3 - "$1" <<'PY'
import json, sys
rows = json.load(open(sys.argv[1]))
order = {"DO": 0, "WARN": 1, "CONSENT": 2}
for st in ("DO", "WARN", "CONSENT"):
    for r in rows:
        if r.get("state") == st:
            print(f"{st} {r['phase']}/{r['name']}/{r['step']}")
print(f"TOTAL {len(rows)}")
PY
}
summarize "$TMP/plan1.json" >"$TMP/s1"
summarize "$TMP/plan2.json" >"$TMP/s2"

count() { grep -c "^$1 " "$TMP/s1" || true; }
rows_of() { awk -v s="$1" '$1 == s { $1=""; sub(/^ /,""); printf "%s, ", $0 }' "$TMP/s1" | sed 's/, $//'; }
TOTAL="$(awk '$1=="TOTAL"{print $2}' "$TMP/s1")"

N_DO="$(count DO)"; N_WARN="$(count WARN)"; N_CONSENT="$(count CONSENT)"
NEED_ACTION=$(( N_DO + N_WARN ))

# --- the clauses ---------------------------------------------------------------
declare -a C_NAME C_STATE C_EVID

add() { C_NAME+=("$1"); C_STATE+=("$2"); C_EVID+=("$3"); }

# C1 — governed here: no row still asks for action.
if [ "$NEED_ACTION" -eq 0 ]; then
  add "C1 governed-here" "PROVEN" "the plan asks for no action (${TOTAL} rows, 0 DO, 0 WARN)"
else
  add "C1 governed-here" "FAILED" "${NEED_ACTION} rows still ask for action: $(rows_of DO)$([ "$N_WARN" -gt 0 ] && printf ' [WARN] %s' "$(rows_of WARN)")"
fi

# C2 — unattended: the only human states are CONSENT rows; there must be none.
if [ "$N_CONSENT" -eq 0 ]; then
  add "C2 unattended" "PROVEN" "no step needs a human (0 CONSENT rows)"
else
  add "C2 unattended" "FAILED" "${N_CONSENT} step(s) need a human: $(rows_of CONSENT)"
fi

# C3 — idempotent: the plan is a pure function of state.
if cmp -s "$TMP/s1" "$TMP/s2"; then
  add "C3 idempotent" "PROVEN" "the plan is identical across two runs (${TOTAL} rows)"
else
  add "C3 idempotent" "FAILED" "the plan changed between two runs: $(diff "$TMP/s1" "$TMP/s2" | head -3 | tr '\n' ' ')"
fi

# C4 — a fresh machine: needs a machine to be fresh on. Named, never faked.
add "C4 fresh-machine" "UNPROVEN" "no fresh machine is provisioned: unproven until the install runs on a new host or container (podman image) that has none of this"

# C5 — removal: there is no uninstaller to run.
if [ -x "$ROOT/bin/ymir-uninstall.sh" ]; then
  add "C5 removal" "UNPROVEN" "an uninstaller exists but its clause is not yet proved against a real home"
else
  add "C5 removal" "GAP" "no uninstaller exists (bin/ymir-uninstall.sh absent): removing the runtime cannot be proved, only named"
fi

# --- verdict -------------------------------------------------------------------
FAILED=0; NOTPROVEN=0; GAPS=0
for i in "${!C_STATE[@]}"; do
  case "${C_STATE[$i]}" in
    FAILED)    FAILED=$((FAILED+1)) ;;
    UNPROVEN)  NOTPROVEN=$((NOTPROVEN+1)) ;;
    GAP)       GAPS=$((GAPS+1)) ;;
  esac
done

if [ "$JSON" = 1 ]; then
  python3 - "${#C_NAME[@]}" "${C_NAME[@]}" "${C_STATE[@]}" "${C_EVID[@]}" <<'PY'
import json, sys
n = int(sys.argv[1])
names, states, evid = sys.argv[2:2+n], sys.argv[2+n:2+2*n], sys.argv[2+2*n:2+3*n]
print(json.dumps([{"clause": a, "state": b, "evidence": c} for a, b, c in zip(names, states, evid)], indent=2))
PY
else
  printf 'prove-install[%s]{clause,state,evidence}:\n' "${#C_NAME[@]}"
  for i in "${!C_NAME[@]}"; do
    printf '  "%s","%s","%s"\n' "${C_NAME[$i]}" "${C_STATE[$i]}" "${C_EVID[$i]}"
  done
  if [ "$FAILED" -gt 0 ]; then
    printf 'verdict: FAILED — %s clause(s) failed; the machine is not yet governed\n' "$FAILED"
  elif [ "$NOTPROVEN" -gt 0 ] || [ "$GAPS" -gt 0 ]; then
    printf 'verdict: INCOMPLETE — %s unproven, %s gap(s); nothing here is claimed as proved\n' "$NOTPROVEN" "$GAPS"
  else
    printf 'verdict: PROVEN — every clause has a command and every command answered\n'
  fi
fi

if [ "$FAILED" -gt 0 ]; then exit 1; fi
if [ "$STRICT" = 1 ] && { [ "$NOTPROVEN" -gt 0 ] || [ "$GAPS" -gt 0 ]; }; then exit 1; fi
exit 0
