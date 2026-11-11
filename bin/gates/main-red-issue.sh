#!/usr/bin/env bash
# main-red-issue.sh — when main is red, ONE issue names the ward and the commit that broke it.
#
# Plan 243 §3, part D/E (2026-11-11). The new pre-push never refuses a push for a fault it did
# not cause: a finding in a file the push did not touch prints `inherited` and the push
# proceeds. That is only honest if SOMETHING still owns the fault — otherwise "not yours" turns
# into "nobody's", and main stays red for a week while every hand pushes past it.
#
# So the workflow runs this on a red main. It reads the verdict `bin/gates/ci-verify.sh` wrote,
# names each failing ward, attributes it to the newest commit that touched the file the ward
# named, and opens ONE issue labelled `main-red`. It never opens a second: an issue already
# open is APPENDED to (Rule 06 — a record is extended, never rewritten).
#
# Usage:
#   main-red-issue.sh                 # read the verdict, print what it would file
#   main-red-issue.sh --apply         # create or append the issue (what the workflow runs)
#   main-red-issue.sh --apply --dry-run   # same, but say it instead of doing it
#
# Environment:
#   YMIR_CI_VERDICT   the verdict file ci-verify.sh wrote (default ${TMPDIR:-/tmp}/ymir-ci-verdict.txt)
#   GITHUB_REPOSITORY the repo (default zerwiz/ymir)
#   GH_TOKEN          for --apply
#
# Exit: 0 filed/printed · 1 nothing to file (main is not red) · 2 usage.
set -u

APPLY=0; DRY=0
for a in "$@"; do
  case "$a" in
    --apply)   APPLY=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown flag %s\nhelp: main-red-issue.sh [--apply] [--dry-run]\n' "$a" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2
VERDICT="${YMIR_CI_VERDICT:-${TMPDIR:-/tmp}/ymir-ci-verdict.txt}"
REPO="${GITHUB_REPOSITORY:-zerwiz/ymir}"
LABEL="main-red"

[ -s "$VERDICT" ] || { printf 'main-red-issue: no verdict at %s — main is not red (or ci-verify did not write one)\n' "$VERDICT"; exit 1; }

# ── what failed, and who broke it ────────────────────────────────────────────
sha="$(git rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')"
subject="$(git log -1 --format=%s 2>/dev/null | cut -c1-80)"
rows=""; ward_rows=""
while IFS=$'\t' read -r gate what; do
  [ -n "$gate" ] || continue
  rows+="| \`$gate\` | $what |"$'\n'
done <"$VERDICT"
if [ -s "$VERDICT.wards" ]; then
  ward_rows="$(grep -E '^  "[^"]+","(FAIL|MISSING)"' "$VERDICT.wards" | head -12 || true)"
fi

# The commit that most likely broke it: the newest commit on main that touched the file a
# failing ward named. A ward that names no path is attributed to main's tip, and said so.
blame_commit() {
  local p="$1" c
  if [ -n "$p" ] && [ -e "$ROOT/$p" ] || [ -n "$p" ] && git cat-file -e "HEAD:$p" 2>/dev/null; then
    c="$(git log -1 --format='%h %s' -- "$p" 2>/dev/null | cut -c1-100)"
    [ -n "$c" ] && { printf '%s' "$c"; return 0; }
  fi
  printf "%s %s" "$sha" "$subject"
}
attribution=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  p="$(printf '%s' "$line" | grep -oE '[A-Za-z0-9_./-]+\.(md|sh|py|ts|mjs|js|json|yml|yaml|nsi|service)' | head -1 || true)"
  attribution+="| $(printf '%s' "$line" | cut -c1-90) | \`$(blame_commit "${p:-}")\` |"$'\n'
done <<EOF
$ward_rows
EOF

stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
body="$(cat <<EOF
## main is red

Filed by \`bin/gates/main-red-issue.sh\` from the CI verdict — one issue, never a second.

- **main at** \`$sha\` — $subject
- **when** $stamp
- **why this exists** the pre-push never refuses a push for a fault it did not cause (plan 243 §3, part D). A fault already on main is printed \`inherited\` and the push proceeds — so *this* issue is what owns it, and every hand can still ship.

### the gates that failed

| gate | what it proves |
|---|---|
${rows:-| (none recorded) | |
}

### the wards that failed, and the commit that most likely broke them

\`\`\`
${ward_rows:-(no ward rows in the verdict)}
\`\`\`

| finding | newest commit touching it |
|---|---|
${attribution:-| (nothing attributable) | |
}

### the remedy

1. Reproduce: \`bash bin/gates/guards.sh --full\` (the whole tree, every ward — what CI runs).
2. Repair it on a branch, open a PR; CI is the required check and it must go green.
3. If the file is GENERATED (a register, \`INDEX.md\`, \`FEATURES.md\`), take main's copy and **regenerate once** — never hand-edit or merge-resolve it.
4. This issue closes when main is green again; the remedy is a PR, never a local merge.

---
_append-only: a later red main appends a dated section here rather than opening a second issue._
EOF
)"

printf 'main-red-issue[3]{field,value}:\n'
printf '  "repo","%s"\n  "label","%s"\n  "main_at","%s"\n' "$REPO" "$LABEL" "$sha"
printf '%s\n' "$rows" | sed 's/^/  verdict: /' | grep -v '^  verdict: $' || true

if [ "$APPLY" -eq 0 ] || [ "$DRY" -eq 1 ]; then
  printf '  "action","would file one issue titled: main is red at %s — %s"\n' "$sha" "$subject"
  [ "$DRY" -eq 1 ] && [ "$APPLY" -eq 1 ] && printf '  "note","--dry-run given: nothing was created"\n'
  printf 'help: run with --apply (and GH_TOKEN set) to create or append the issue\n'
  printf '%s\n' "$body" | head -20
  exit 0
fi

# The label may not exist on the repo yet, so the search is by TITLE — a gate that depends on a
# hand having created a label first is a gate that files nothing.
existing="$(gh issue list --repo "$REPO" --state open --search 'main is red in:title' --json number -q '.[0].number' 2>/dev/null || true)"
if [ -n "$existing" ]; then
  # APPEND, never rewrite (Rule 06): a dated section on the issue that already owns the fault.
  old="$(gh issue view "$existing" --repo "$REPO" --json body -q .body 2>/dev/null || true)"
  printf '%s\n\n---\n\n## Appended %s — main is red again at `%s`\n\n%s\n' "$old" "$stamp" "$sha" "$body" >"$VERDICT.body"
  gh issue edit "$existing" --repo "$REPO" --body-file "$VERDICT.body" >/dev/null && \
    printf '  "action","appended a dated section to issue #%s"\n' "$existing"
  exit 0
fi
have_label="$(gh label list --repo "$REPO" --json name -q '.[].name' 2>/dev/null | grep -qx "$LABEL" && printf yes || true)"
url="$(gh issue create --repo "$REPO" ${have_label:+--label "$LABEL"} \
        --title "main is red at $sha — $subject" --body "$body" 2>/dev/null || true)"
if [ -n "$url" ]; then
  printf '  "action","opened %s"\n' "$url"
  exit 0
fi
printf '  "action","could not file (no gh auth, no label %s, or the API refused) — the verdict is above"\n' "$LABEL" >&2
exit 1
