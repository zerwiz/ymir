#!/usr/bin/env bash
# main-red.sh — ONE issue names a red main, and it names the hand that broke it.
#
# WHY (plan 243 part E, 2026-11-11). The gate was already red on main for four consecutive
# commits and NOTHING IN THE HOUSE SAID SO. The only way to learn it was to open a browser,
# find the latest run on main, and read ten minutes of log: measured that night, four red
# pushes in a row (7m30s, 10m16s, 10m36s, 10m19s), each one invisible to every seat and every
# agent, while the arm-holder's own audit recorded "main red tonight on inventory, registers,
# features, weave, public-data". A red main is not the problem — a SILENT red main is, because
# every hand then pushes into it and every push fails for drift it did not cause.
#
# So: on a red `main` push the workflow opens — or updates, never a second one — exactly one
# issue labelled `main-red`, carrying
#   · which gates failed,
#   · the ward's own finding, quoted, with the file it names,
#   · the commit that broke it, attributed over the range from the LAST GREEN RUN to this one,
#   · the run, the sha, and the two commands that reproduce it.
# It closes itself when main is green again (the verdict is a fact, not a person).
#
# A RED PULL REQUEST OPENS NOTHING. It is already red in its own checks, it is the author's to
# fix, and an issue per branch would be an inbox nobody reads. The workflow enforces that; this
# script refuses to invent a second policy.
#
# Usage:
#   main-red.sh summary --log FILE                 # markdown for the run page
#   main-red.sh report  --log FILE [--since SHA] [--sha SHA] [--run-url URL]
#                                                  # print the issue it would file (no network)
#   main-red.sh open    --log FILE [--since SHA] [--sha SHA] [--run-url URL]
#                                                  # open or update the ONE `main-red` issue
#   main-red.sh close   [--sha SHA] [--run-url URL]  # close the open one: main is green
#   main-red.sh --label                            # the label this door owns
#
# Exit: 0 did what was asked · 1 nothing to report / nothing open · 3 unavailable (no gh, no
#       token, no log) · 2 usage.
set -uo pipefail

LABEL="main-red"
VERSION="1.0.0"

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

MODE=""; LOG=""; SINCE=""; SHA=""; RUN_URL=""
while [ $# -gt 0 ]; do
  case "$1" in
    summary|report|open|close) MODE="$1"; shift ;;
    --log)     LOG="${2-}"; shift 2 ;;
    --since)   SINCE="${2-}"; shift 2 ;;
    --sha)     SHA="${2-}"; shift 2 ;;
    --run-url) RUN_URL="${2-}"; shift 2 ;;
    --label)   printf '%s\n' "$LABEL"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    --version) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { usage >&2; exit 2; }
case "$MODE" in
  report|open|summary) [ -n "$LOG" ] || { printf 'error: --log FILE is required for %s\n' "$MODE" >&2; exit 2; } ;;
esac
if [ -n "$LOG" ]; then
  [ -r "$LOG" ] || { printf 'unavailable: the gate log %s is not readable\n' "$LOG" >&2; exit 3; }
fi

# ---------------------------------------------------------------- what the log says failed
# CI prints TOON rows. Two blocks carry the verdicts:
#   ci_verify[N]{gate,status,detail}:     one row per CI gate
#   guards[N]{ward,status,finding}:       one row per tree ward, inside the `ward` gate
# A FAIL row's own detail sits on the same line; the lines UNDER it (four spaces) are the
# gate's tail — the finding, quoted. Both are carried, because the row alone is a name and
# the tail is the reason.

FAIL_GATES=()   # "name<TAB>detail"
FAIL_WARDS=()   # "name<TAB>detail"
DETAILS="$(mktemp "${TMPDIR:-/tmp}/main-red-details-XXXXXX")"
trap 'rm -f "$DETAILS"' EXIT

section=""
last_gate=""
last_ward=""
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    *ci_verify\[*) section="ci" ;;
    *guards\[*)    section="ward" ;;
  esac
  # a FAIL row (the ward block sits indented inside the gate's tail, so leading space is free)
  if printf '%s' "$line" | grep -qE '^[[:space:]]*"[^"]+","FAIL",'; then
    name="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*"\([^"]*\)","FAIL","\(.*\)"$/\1/p')"
    [ -n "$name" ] || name="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*"\([^"]*\)".*/\1/p')"
    detail="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*"[^"]*","FAIL","\(.*\)"$/\1/p')"
    if [ "$section" = "ward" ]; then
      FAIL_WARDS+=("$name"$'\t'"$detail"); last_ward="$name"; last_gate=""
    else
      FAIL_GATES+=("$name"$'\t'"$detail"); last_gate="$name"; last_ward=""
    fi
    continue
  fi
  # any other row (PASS/SKIP/NOTE/MISSING) ends a tail and is not a detail
  if printf '%s' "$line" | grep -qE '^[[:space:]]*"[^"]+","[A-Z]+",'; then
    last_gate=""; last_ward=""; continue
  fi
  # a continuation line: the failing gate's own tail
  if printf '%s' "$line" | grep -qE '^    [^ ]'; then
    if [ -n "$last_gate" ]; then printf '%s\t%s\n' "$last_gate" "$(printf '%s' "$line" | sed 's/^    //')" >> "$DETAILS"
    elif [ -n "$last_ward" ]; then printf 'ward:%s\t%s\n' "$last_ward" "$(printf '%s' "$line" | sed 's/^    //')" >> "$DETAILS"
    fi
    continue
  fi
done < "$LOG"

nfails=$(( ${#FAIL_GATES[@]} + ${#FAIL_WARDS[@]} ))

tail_of() { # <key> — the continuation lines recorded for one gate or ward
  [ -s "$DETAILS" ] || return 0
  awk -F'\t' -v k="$1" '$1==k { print "    " $2 }' "$DETAILS"
}

# ------------------------------------------------------------------ who broke it, and when
# The range is LAST GREEN RUN..this commit. The last green is what makes the answer a commit
# and not a guess: everything after it is what main did not have when it was green.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" 2>/dev/null || true

have_gh() { command -v gh >/dev/null 2>&1 && [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; }
export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

discover_since() {
  [ -n "$SINCE" ] && return 0
  have_gh || return 0
  local wf=".github/workflows/ymir-gates.yml"
  SINCE="$(gh api "repos/{owner}/{repo}/actions/workflows/${wf}/runs?branch=main&status=success&per_page=1" \
            --jq '.workflow_runs[0].head_sha // empty' 2>/dev/null || true)"
}

# paths named by a finding — a path is the fastest route from a ward to a commit
paths_of_findings() {
  { for r in "${FAIL_GATES[@]}" "${FAIL_WARDS[@]}"; do printf '%s\n' "${r#*$'\t'}"; done
    [ -s "$DETAILS" ] && cut -f2- "$DETAILS"
  } | grep -oE '[A-Za-z0-9_./@+-]+\.(md|sh|py|ts|mts|mjs|cjs|js|json|yaml|yml|txt|toml|ini|conf|service|desktop|nsi)' \
    | sed 's/^\.\///' | sort -u
}

resolve_paths() {
  local p out=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then out="$out $p"; continue; fi
    local hit; hit="$(git ls-files -- "*$p" 2>/dev/null | head -1)"
    [ -n "$hit" ] && out="$out $hit"
  done
  printf '%s' "${out# }"
}

range_commits() { # <spec>… — newline "sha<TAB>subject" for a range, at most 6
  git log --no-merges --format='%h%x09%s' "$@" 2>/dev/null | head -6
}

attribute() {
  discover_since
  local head; head="$(git rev-parse --short HEAD 2>/dev/null || true)"
  [ -n "$head" ] && printf 'the commit this run judged: `%s` %s\n\n' "$head" \
    "$(git log -1 --format='%s (%an, %ad)' --date=short 2>/dev/null || true)"

  local range=""
  if [ -n "$SINCE" ] && git cat-file -e "${SINCE}^{commit}" 2>/dev/null; then
    if [ "$(git rev-parse "$SINCE^{commit}")" = "$(git rev-parse 'HEAD^{commit}')" ]; then
      printf 'the last green run was **this very commit** — the fault is not a new commit but something\n'
      printf 'that only CI sees (an environment, a fetch, a token). Re-run before blaming a hand.\n'
      return 0
    fi
    range="${SINCE}..HEAD"
    printf 'the range judged: the last **green** main run (`%s`) up to this commit — %s commit(s)\n\n' \
      "$(printf '%s' "$SINCE" | cut -c1-9)" "$(git rev-list --count "$range" 2>/dev/null || printf '?')"
  else
    printf 'the range judged: **unknown** — no earlier green main run was recorded, so the blame cannot\n'
    printf 'be narrowed to a commit. The ward and its finding below are still exact; run `git log` on the\n'
    printf 'files it names to find the hand.\n\n'
  fi

  local paths; paths="$(paths_of_findings | resolve_paths)"
  local hits=""
  if [ -n "$paths" ] && [ -n "$range" ]; then
    # shellcheck disable=SC2086
    hits="$(range_commits "$range" -- $paths)"
  fi

  if [ -n "$hits" ]; then
    local n; n="$(printf '%s\n' "$hits" | grep -c . || true)"
    if [ "$n" -eq 1 ]; then
      printf '**the commit that broke it:** `%s`\n' "$(printf '%s' "$hits" | tr '\t' ' ')"
    else
      printf '**the commits that touched the files the finding names** (%s in the range):\n\n' "$n"
      printf '%s\n' "$hits" | while IFS=$'\t' read -r s t; do printf -- '- `%s` %s\n' "$s" "$t"; done
    fi
    printf '\n'
    return 0
  fi

  if [ -n "$range" ]; then
    hits="$(range_commits "$range")"
    if [ -n "$hits" ]; then
      printf '**no commit in the range touched the files the finding names**, so the whole range is named:\n\n'
      printf '%s\n' "$hits" | while IFS=$'\t' read -r s t; do printf -- '- `%s` %s\n' "$s" "$t"; done
      printf '\n'
    fi
  fi
}

# ------------------------------------------------------------------------------- the issue
issue_title() {
  local head=""
  if [ "${#FAIL_GATES[@]}" -gt 0 ]; then head="${FAIL_GATES[0]%%$'\t'*}"; else head="ward:${FAIL_WARDS[0]%%$'\t'*}"; fi
  local more=0
  more=$(( nfails - 1 ))
  local one=""
  if [ "${#FAIL_GATES[@]}" -gt 0 ]; then one="${FAIL_GATES[0]#*$'\t'}"; else one="${FAIL_WARDS[0]#*$'\t'}"; fi
  if [ -z "$one" ] && [ -s "$DETAILS" ]; then
    one="$(awk -F'\t' '{ print $2; exit }' "$DETAILS")"
  fi
  local title="main is red: ${head}"
  [ "$more" -gt 0 ] && title="${title} (+${more} more)"
  if [ -n "$one" ]; then
    printf '%s — %s\n' "$title" "$(printf '%s' "$one" | cut -c1-90)"
  else
    printf '%s\n' "$title"
  fi
}

issue_body() {
  printf '<!-- main-red: filed and updated by bin/gates/main-red.sh from the newest red run of `main`. -->\n'
  printf '**`main` is red.** This is the one issue for it; it is UPDATED on the next red run and CLOSED by the\n'
  printf 'first green one. Do not file a second.\n\n'

  printf '## What failed (%s)\n\n' "$nfails"
  if [ "${#FAIL_GATES[@]}" -gt 0 ]; then
    printf 'CI gates:\n\n'
    for r in "${FAIL_GATES[@]}"; do
      printf -- '- **%s** — %s\n' "${r%%$'\t'*}" "${r#*$'\t'}"
      tail_of "${r%%$'\t'*}"
    done
    printf '\n'
  fi
  if [ "${#FAIL_WARDS[@]}" -gt 0 ]; then
    printf 'Tree wards (`bin/gates/guards/`):\n\n'
    for r in "${FAIL_WARDS[@]}"; do
      printf -- '- **%s** — %s\n' "${r%%$'\t'*}" "${r#*$'\t'}"
      tail_of "ward:${r%%$'\t'*}"
    done
    printf '\n'
  fi

  printf '## Who broke it\n\n'
  attribute
  if [ -n "$SHA" ]; then printf 'run: `%s`\n\n' "$(printf '%s' "$SHA" | cut -c1-12)"; fi
  if [ -n "$RUN_URL" ]; then printf 'the run: %s\n\n' "$RUN_URL"; fi

  printf '## Clear it\n\n'
  printf '```bash\nbin/gates/ci-verify.sh          # the whole suite, in one command\nbin/gates/guards.sh             # the tree wards on their own\n'
  if [ "${#FAIL_GATES[@]}" -gt 0 ]; then printf '# failing CI gates:'; for r in "${FAIL_GATES[@]}"; do printf ' %s' "${r%%$'\t'*}"; done; printf '\n'; fi
  printf '```\n\n'
  if [ "${#FAIL_WARDS[@]}" -gt 0 ]; then
    printf 'The wards that failed, each of which runs on its own:\n\n```bash\n'
    for r in "${FAIL_WARDS[@]}"; do printf 'bash bin/gates/guards/%s check\n' "${r%%$'\t'*}"; done
    printf '```\n\n'
  fi
  printf 'A ward names the file and the line; fix the thing it names, open a PR, and this issue closes itself\n'
  printf 'when `main` is green again. Never `--no-verify` past it: the gate exists so that a red main cannot be\n'
  printf 'merged into, and the bypass is what makes the red permanent.\n'
}

# -------------------------------------------------------------------------------- summary
do_summary() {
  printf '## The whole-tree gate\n\n'
  if [ "$nfails" -eq 0 ]; then
    printf '**green** — every CI gate passed on this tree.\n'
    return 0
  fi
  printf '**RED** — %s failing.\n\n' "$nfails"
  printf '| what | finding |\n|---|---|\n'
  for r in "${FAIL_GATES[@]}" "${FAIL_WARDS[@]}"; do
    printf '| `%s` | %s |\n' "${r%%$'\t'*}" "$(printf '%s' "${r#*$'\t'}" | tr -d '\n' | sed 's/|/\\|/g')"
  done
  printf '\n'
  if [ -s "$DETAILS" ]; then
    printf '<details><summary>the failing gates&#39; own words</summary>\n\n```\n'
    cut -f2- "$DETAILS"
    printf '```\n\n</details>\n'
  fi
  if [ "$MODE" = summary ]; then
    printf '\nThe one issue for a red main is `%s` (opened and closed by the workflow).\n' "$LABEL"
  fi
}

# ------------------------------------------------------------------------------ gh, the door
ensure_label() {
  gh label create "$LABEL" \
     --description "main is red — filed and closed by bin/gates/main-red.sh" \
     --color "B60205" >/dev/null 2>&1 || true
}

open_issue() {
  command -v gh >/dev/null 2>&1 || { printf 'unavailable: gh is not installed on this host — the alarm needs it\n' >&2; exit 3; }
  [ -n "${GH_TOKEN:-}" ] || { printf 'unavailable: GH_TOKEN is empty — the alarm cannot write an issue\n' >&2; exit 3; }
  ensure_label
  local title body n
  title="$(issue_title)"
  body="$(issue_body)"
  n="$(gh issue list --label "$LABEL" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [ -n "$n" ]; then
    printf '%s' "$body" | gh issue edit "$n" --title "$title" --body-file - >/dev/null || {
      printf 'unavailable: could not update issue #%s\n' "$n" >&2; exit 3; }
    printf 'main-red: updated the one issue, #%s\n' "$n"
  else
    printf '%s' "$body" | gh issue create --title "$title" --body-file - --label "$LABEL" >/dev/null || {
      printf 'unavailable: could not open the issue\n' >&2; exit 3; }
    printf 'main-red: opened the one issue for a red main\n'
  fi
}

close_issue() {
  command -v gh >/dev/null 2>&1 || { printf 'unavailable: gh is not installed on this host\n' >&2; exit 3; }
  [ -n "${GH_TOKEN:-}" ] || { printf 'unavailable: GH_TOKEN is empty\n' >&2; exit 3; }
  local nums; nums="$(gh issue list --label "$LABEL" --state open --json number --jq '.[].number' 2>/dev/null || true)"
  if [ -z "$nums" ]; then printf 'main-red: main is green and no issue was open — nothing to close\n'; return 0; fi
  local note="main is green again"
  [ -n "$SHA" ] && note="$note at \`$(printf '%s' "$SHA" | cut -c1-12)\`"
  [ -n "$RUN_URL" ] && note="$note ($RUN_URL)"
  for n in $nums; do
    printf '%s\n' "$note" | gh issue comment "$n" --body-file - >/dev/null 2>&1 || true
    gh issue close "$n" --reason completed >/dev/null 2>&1 || {
      printf 'unavailable: could not close issue #%s\n' "$n" >&2; exit 3; }
    printf 'main-red: closed #%s — %s\n' "$n" "$note"
  done
}

case "$MODE" in
  summary) do_summary ;;
  report)
    if [ "$nfails" -eq 0 ]; then printf 'main-red: the log carries no FAIL row — nothing to report\n'; exit 1; fi
    printf 'title: %s\n\n' "$(issue_title)"
    issue_body
    ;;
  open)
    if [ "$nfails" -eq 0 ]; then printf 'main-red: the log carries no FAIL row — no issue is opened\n'; exit 1; fi
    open_issue
    ;;
  close) close_issue ;;
esac
