#!/usr/bin/env bash
# nornir-job-forgejo-git.sh — the local git round: issues and PRs on the forge.
#
# The Forgejo door (forgejo.zerwiz.org → the server's :3030, or a locally
# provisioned forge via bin/ymir-marketing-stack.sh --with-forgejo) holds the
# Allfather's issue-to-PR loop. Each morning this job reads the forge's open
# issues, lands a public-safe digest in the hoard, and carves a Rune with the
# tally — so a broken door or an accumulating queue is seen at sunrise, never
# found by accident.
#
# The forge address comes from the USER'S home, never the tree (Rule 04/07):
#   $YMIR_HOME/config/forge.env :  FORGEJO_URL=...  FORGEJO_TOKEN=... (optional)
# Stateless: read the door → list issues → write one digest → carve one Rune.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
ymir_home_root _HOME

FORGE_ENV="$_HOME/config/forge.env"
[ -r "$FORGE_ENV" ] && . "$FORGE_ENV"
FORGEJO_URL="${FORGEJO_URL:-}"
FORGEJO_TOKEN="${FORGEJO_TOKEN:-}"

# No address configured — nothing scheduled, exit clean (the same honest shape
# as a scrape round with no sources).
if [ -z "$FORGEJO_URL" ]; then
  printf 'forgejo-git: no FORGEJO_URL in %s — issues loop not armed (exit 0)\n' "$FORGE_ENV"
  exit 0
fi

# The API base: https://host/api/v1 (Forgejo/Gitea compatible).
API="${FORGEJO_URL%/}/api/v1"
AUTH=()
[ -n "$FORGEJO_TOKEN" ] && AUTH=(-H "Authorization: token $FORGEJO_TOKEN")

# The door must actually answer — a dead tunnel is reported, not guessed.
if ! curl -fsS --max-time 15 "${AUTH[@]}" "$API/version" >/dev/null 2>&1; then
  printf 'forgejo-git: door closed at %s (tunnel down?) — issues not listed\n' "$FORGEJO_URL"
  # shellcheck source=bin/runes-append.sh
  . "$ROOT/bin/runes-append.sh"
  runes_append "forgejo" "git.door-down" --realm "${BROKK_REALM:-}" \
    --message "Forgejo door closed at $FORGEJO_URL — tunnel or service down" >/dev/null 2>&1 || true
  exit 1
fi

# All repos' open issues (the forge API lists them per repo; we query the
# user's token scope: /repos/issues/search?type=issues&state=open).
ISSUES_JSON="$(curl -fsS --max-time 25 "${AUTH[@]}" \
  "$API/repos/issues/search?type=issues&state=open&limit=50" 2>/dev/null)" || ISSUES_JSON="[]"

COUNT=$(printf '%s' "$ISSUES_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
ISSUES="$(printf '%s' "$ISSUES_JSON" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for i in d[:15]:
        repo=(i.get('repository') or {}).get('full_name','?')
        print('- [%s] %s (@%s)' % (repo, i.get('title','?')[:90], i.get('user',{}).get('login','?')))
except Exception:
    pass
" 2>/dev/null)"

TODAY="$(date -u +%Y-%m-%d)"
DIGEST="$_HOME/memory/daily/forgejo-$TODAY.md"
mkdir -p "$(dirname "$DIGEST")"
{
  printf '# Forgejo issues — %s\n\n' "$TODAY"
  printf '%s open (limit 50 scanned; first 15 shown)\n\n' "$COUNT"
  printf '%s\n' "$ISSUES"
} >"$DIGEST"

printf 'forgejo-git: issues=%s digest=%s\n' "$COUNT" "$DIGEST"

# shellcheck source=bin/runes-append.sh
. "$ROOT/bin/runes-append.sh"
runes_append "forgejo" "git.issues" --realm "${BROKK_REALM:-}" \
  --message "forgejo issues round: $COUNT open -> $DIGEST" >/dev/null \
  || printf 'forgejo-git: rune append failed (non-fatal)\n'
exit 0