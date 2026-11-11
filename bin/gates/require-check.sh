#!/usr/bin/env bash
# require-check.sh — make the `gates` job the REQUIRED check on main.
#
# Plan 243 §3, part E. The workflow is only the binding gate if GitHub refuses a merge while it
# is red; a check nobody requires is a suggestion, and the fastest road becomes the one that
# ignores it. This door sets exactly one thing — the required status check — and touches nothing
# else in the branch protection (no review rules, no force-push flags, no push restrictions).
#
#   require-check.sh            # print the current state and the command it would run
#   require-check.sh --apply    # seat it (needs admin on the repo)
#
# Exit: 0 printed/seated · 1 could not read the protection (not an admin, or no auth) · 2 usage.
set -u

REPO="${GITHUB_REPOSITORY:-zerwiz/ymir}"
BRANCH="${YMIR_PROTECTED_BRANCH:-main}"
CHECK="${YMIR_GATES_CHECK:-gates}"     # the job name in .github/workflows/ymir-gates.yml

APPLY=0
case "${1-}" in
  --apply) APPLY=1 ;;
  -h|--help|"") ;;
  *) printf 'error: unknown flag %s\nhelp: require-check.sh [--apply]\n' "$1" >&2; exit 2 ;;
esac

printf 'require_check[3]{field,value}:\n'
printf '  "repo","%s"\n  "branch","%s"\n  "required_check","%s"\n' "$REPO" "$BRANCH" "$CHECK"

current="$(gh api "repos/$REPO/branches/$BRANCH/protection/required_status_checks" -q '.contexts | join(",")' 2>/dev/null || true)"
if [ -n "$current" ]; then
  printf '  "now","%s"\n' "$current"
  case ",$current," in *",$CHECK,"*) printf '  "result","already required — nothing to do"\n'; exit 0 ;; esac
else
  printf '  "now","unreadable (no admin token, or branch protection is off)"\n'
fi

if [ "$APPLY" -eq 0 ]; then
  printf '  "action","would run:"\n'
  printf '    gh api -X PATCH repos/%s/branches/%s/protection/required_status_checks -f strict=false -F "contexts[]=%s"\n' "$REPO" "$BRANCH" "$CHECK"
  printf 'help: --apply seats it; that needs admin on the repo and the Allfather'"'"'s word\n'
  exit 0
fi

if gh api -X PATCH "repos/$REPO/branches/$BRANCH/protection/required_status_checks" \
     -f strict=false -F "contexts[]=$CHECK" >/dev/null 2>&1; then
  printf '  "result","seated — a PR can no longer merge while %s is red"\n' "$CHECK"
  exit 0
fi
printf '  "result","the API refused — the token is not an admin, or protection would have to be enabled first"\n' >&2
exit 1
