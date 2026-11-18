#!/usr/bin/env bash
# require-check.sh — the required status check on main, read WHOLE and written without loss.
#
# Plan 243 §3 part E, corrected 2026-11-16 (the reviewer's item 1: "main has no branch protection").
# The workflow is only the binding gate if GitHub refuses a merge while it is red; a check nobody
# requires is a suggestion, and the fastest road becomes the one that ignores it.
#
# WHAT THIS DOOR LEARNED THE HARD WAY. It used to default its check name to `gates` and PATCH the
# required set with exactly that one context. Measured on 2026-11-16: main's required context is
# `whole-tree` (the job in .github/workflows/ymir-gates.yml), and there is no `gates` job at all —
# so `--apply` would have REPLACED the one check that guards main with a name GitHub has never
# seen, and a required check that does not exist is read as satisfied. A door that writes the
# protection must first read all of it.
#
#   require-check.sh                  # print the protection as measured, and what it would change
#   require-check.sh --apply          # ADD the check to the required set; drop nothing
#   require-check.sh --strict on|off  # with --apply, also set "require branches to be up to date"
#
# `strict` (up-to-date before merge) is NOT flipped by this door unless it is asked for on the
# command line: it was turned OFF on 2026-11-15 on purpose (plan 295 §S2) because with it on,
# every merge moved main under every other pull request and the queue drained one PR per CI run.
# A repair that quietly turned it back on would restore the starvation.
#
# Exit: 0 printed/seated · 1 could not read the protection, or the API refused · 2 usage.
set -u

REPO="${GITHUB_REPOSITORY:-zerwiz/ymir}"
BRANCH="${YMIR_PROTECTED_BRANCH:-main}"
# The job name in .github/workflows/ymir-gates.yml, which says of itself: "THE REQUIRED CHECK. This
# job name is the contract with branch protection: rename it and the protection points at a check
# that no longer exists, which GitHub reads as satisfied."
CHECK="${YMIR_GATES_CHECK:-whole-tree}"

APPLY=0
STRICT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --strict) shift || { printf 'error: --strict needs on|off\n' >&2; exit 2; }
              STRICT="${1-}"
              case "$STRICT" in on|true|1) STRICT=true ;; off|false|0) STRICT=false ;;
                *) printf 'error: --strict takes on|off, not %s\n' "$STRICT" >&2; exit 2 ;; esac ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown flag %s\nhelp: require-check.sh [--apply] [--strict on|off]\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

printf 'require_check[4]{field,value}:\n'
printf '  "repo","%s"\n  "branch","%s"\n  "check","%s"\n' "$REPO" "$BRANCH" "$CHECK"

# ── 1 · READ the whole protection ───────────────────────────────────────────
# One read, one JSON document: the required contexts, `strict`, the review rule, the admin rule and
# the push/force flags all live in it. Reading one field and writing that field back is how the
# old shape lost the others.
prot="$(gh api "repos/$REPO/branches/$BRANCH/protection" 2>/dev/null)" || prot=""
if [ -z "$prot" ]; then
  printf '  "result","unreadable — branch protection is off, or the token is not an admin"\n'
  printf 'help: it is the operator'"'"'s hand on GitHub (plan 279 §3): Settings → Branches → protect %s,\n' "$BRANCH"
  printf '      then this door reads what was set.\n'
  exit 1
fi

read -r contexts strict reviews admins <<EOF
$(printf '%s' "$prot" | python3 -c '
import json, sys
d = json.load(sys.stdin)
sc = d.get("required_status_checks") or {}
ctx = ",".join(sc.get("contexts") or [])
strict = "true" if sc.get("strict") else "false"
rev = (d.get("required_pull_request_reviews") or {}).get("required_approving_review_count", 0)
admins = "true" if (d.get("enforce_admins") or {}).get("enabled") else "false"
def b(v): return "false" if v else "true"
print(ctx or "-", strict, rev or 0, admins)
')
EOF

printf '  "now_required","%s"\n' "$contexts"
printf '  "up_to_date_required","%s"\n' "$strict"
printf '  "required_reviews","%s"\n' "$reviews"
printf '  "admins_enforced","%s"\n' "$admins"

# The rulesets ride alongside the classic protection, and they are the half an agent must also
# know about before proposing a change: a delete or a force-push of main is refused today by
# "main keeps its history", not by the classic settings.
gh api "repos/$REPO/rulesets" 2>/dev/null | python3 -c '
import json, sys
try: rows = json.load(sys.stdin)
except Exception: sys.exit(0)
active = [r for r in rows if r.get("enforcement") == "active"]
if not active:
    print("  \"rulesets\",\"none active\"")
else:
    for r in active:
        print("  \"ruleset\",\"%s · %s\"" % (r.get("name"), r.get("enforcement")))
' 2>/dev/null || true

# ── 2 · SAY what is missing, and what it costs ──────────────────────────────
case ",$contexts," in
  *",$CHECK,"*) have_check=1 ;;
  *) have_check=0 ;;
esac
[ "$have_check" = 1 ] \
  && printf '  "result","%s is required — a PR cannot merge while it is red"\n' "$CHECK" \
  || printf '  "result","%s is NOT in the required set"\n' "$CHECK"
[ "$reviews" = 0 ] && printf '  "review","none required — a green check is the whole of the gate"\n'
[ "$admins" = false ] && printf '  "admins","not enforced — an administrator can merge past a red check"\n'
[ "$strict" = false ] && printf '  "up_to_date","not required — turned off 2026-11-15 (plan 295 §S2) to end a starvation"\n'

# ── 3 · WRITE only what was asked, and never drop a check ───────────────────
if [ "$APPLY" -eq 0 ]; then
  [ "$have_check" = 1 ] && { printf '  "action","nothing to do"\n'; exit 0; }
  printf '  "action","would run (adds %s, keeps %s, keeps up_to_date=%s):"\n' "$CHECK" "$contexts" "$strict"
  printf '    gh api -X PATCH repos/%s/branches/%s/protection/required_status_checks \\\n' "$REPO" "$BRANCH"
  printf '      -f strict=%s -F "contexts[]=%s" ...\n' "$strict" "$CHECK"
  printf 'help: --apply seats it; that needs admin on the repo and the operator'"'"'s word\n'
  exit 0
fi

[ -n "$STRICT" ] || STRICT="$strict"
[ "$STRICT" = "$strict" ] || printf '  "warn","this apply also changes up_to_date %s -> %s (it was set off on purpose)"\n' "$strict" "$STRICT"

# The union, so a door that was asked for one check cannot take another one away.
args=()
IFS=',' read -r -a existing <<<"$contexts"
for c in "${existing[@]}"; do
  [ -n "$c" ] && [ "$c" != "-" ] && args+=(-F "contexts[]=$c")
done
case ",$contexts," in *",$CHECK,"*) ;; *) args+=(-F "contexts[]=$CHECK") ;; esac

if gh api -X PATCH "repos/$REPO/branches/$BRANCH/protection/required_status_checks" \
     -f strict="$STRICT" "${args[@]}" >/dev/null 2>&1; then
  printf '  "result","seated — required: %s%s; a PR can no longer merge while any is red"\n' \
    "$contexts" "$(case ",$contexts," in *",$CHECK,"*) ;; *) printf ',%s' "$CHECK" ;; esac)"
  exit 0
fi
printf '  "result","the API refused — the token is not an admin, or protection would have to be enabled first"\n' >&2
exit 1
