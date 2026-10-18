#!/usr/bin/env bash
# Unit tests for bin/gates/guards/fixes-guard.sh — the record gate.
#
# The defect this test exists for: a push whose only ref is a branch DELETION was
# judged as if it delivered content. Git feeds a delete as an all-zero local sha,
# the guard's loop skipped it, `head_sha` fell back to HEAD, the range to the base
# was empty, and the push was refused with "refused — no fix note in this range".
# So `git push origin --delete <a-merged-branch>` needed --no-verify.
#
# What the gate actually says: a push that delivers changes must carry a fix note
# naming what it changed. A deletion delivers no content, so it owes no note —
# and whether a deletion touches a PROTECTED branch is branch-guard's business.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/bin/gates/guards/fixes-guard.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A scratch repo the guard can root at (`.pi` + `RULES` are what _root() walks up
# to), with a base commit and a feature branch that changes a bin/ door.
REPO="$TMP/repo"
mkdir -p "$REPO/bin/gates/guards" "$REPO/.pi" "$REPO/RULES" "$REPO/docs/fixes/agents"
cp "$GUARD" "$REPO/bin/gates/guards/fixes-guard.sh"
chmod +x "$REPO/bin/gates/guards/fixes-guard.sh"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.email t@t
git -C "$REPO" config user.name t
printf 'base\n' > "$REPO/bin/door.sh"
git -C "$REPO" add -A >/dev/null
git -C "$REPO" commit -qm base
BASE="$(git -C "$REPO" rev-parse HEAD)"

# A feature commit that DELIVERS content but records nothing.
git -C "$REPO" checkout -q -b feature
printf 'changed\n' >> "$REPO/bin/door.sh"
git -C "$REPO" add -A >/dev/null
git -C "$REPO" commit -qm "change with no fix note"
NO_NOTE="$(git -C "$REPO" rev-parse HEAD)"

# And one that DOES carry a fix note.
printf -- '## agents · unversioned · 2026-10-18 — a thing\n\n### Why\n- x\n' \
  > "$REPO/docs/fixes/agents/unversioned-a-thing.md"
git -C "$REPO" add -A >/dev/null
git -C "$REPO" commit -qm "change with a fix note"
WITH_NOTE="$(git -C "$REPO" rev-parse HEAD)"

ZERO=0000000000000000000000000000000000000000
run() { printf '%s\n' "$1" | bash "$REPO/bin/gates/guards/fixes-guard.sh" >/dev/null 2>&1; }

# ── 1. a delivery with NO fix note is refused ────────────────────────────────
if run "refs/heads/feature $NO_NOTE refs/heads/feature $BASE"; then
  bad "a delivery with no fix note was allowed"
else
  ok "a delivery with no fix note is refused"
fi

# ── 2. a delivery WITH a fix note is allowed ─────────────────────────────────
if run "refs/heads/feature $WITH_NOTE refs/heads/feature $BASE"; then
  ok "a delivery carrying a fix note is allowed"
else
  bad "a delivery carrying a fix note was refused (the note was real)"
fi

# ── 3. a branch DELETION owes no note (the bug) ──────────────────────────────
if run "(delete) $ZERO refs/heads/feature $WITH_NOTE"; then
  ok "a branch deletion is allowed without a fix note"
else
  bad "a branch deletion demanded a fix note (the bug)"
fi

printf '\n%s\n' "----------------------------------------"
if [ "$fail" = 0 ]; then printf 'fixes-guard-deletion.test.sh: all passed\n'; else printf 'fixes-guard-deletion.test.sh: FAILED\n' >&2; fi
exit "$fail"
