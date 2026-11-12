#!/usr/bin/env bash
# Unit tests for the document road — RULES/08, appended 2026-11-12.
#
# The Allfather's word: "documents should be able to push on main." A push that
# lands on main is allowed when every file it changes is a document by the exact
# set in bin/gates/guards/branch-guard.sh; anything else still leaves by PR. The
# fixes-guard owes no note for a document-only range, unless a rule changed.
#
# Each case builds a real commit on a scratch main and feeds the guard the exact
# line git gives a pre-push hook: <local-ref> <local-sha> <remote-ref> <remote-sha>.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO="$TMP/repo"
mkdir -p "$REPO/bin/gates/guards" "$REPO/.pi" "$REPO/RULES" "$REPO/docs/guides" \
         "$REPO/docs/fixes/gates" "$REPO/docs/features/_catalogue" "$REPO/apps/x"
cp "$ROOT/bin/gates/guards/branch-guard.sh" "$ROOT/bin/gates/guards/fixes-guard.sh" "$REPO/bin/gates/guards/"
chmod +x "$REPO"/bin/gates/guards/*.sh
G="$REPO/bin/gates/guards/branch-guard.sh"
F="$REPO/bin/gates/guards/fixes-guard.sh"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.email t@t
git -C "$REPO" config user.name t

printf '# Rule 99\n\nThe old law.\n' > "$REPO/RULES/99-a-rule.md"
printf '# A guide\n\nLine one.\n' > "$REPO/docs/guides/a.md"
printf 'old\n' > "$REPO/docs/fixes/gates/old-note.md"
printf 'row\n' > "$REPO/docs/features/_catalogue/rows.md"
printf 'echo hi\n' > "$REPO/apps/x/run.sh"
printf '# agents\n' > "$REPO/AGENTS.md"
git -C "$REPO" add -A >/dev/null
git -C "$REPO" commit -qm base
BASE="$(git -C "$REPO" rev-parse HEAD)"

# commit_on_base <msg> <shell…> -> prints the new sha; each case starts from BASE.
commit_on_base() {
  local msg="$1"; shift
  git -C "$REPO" checkout -q -f "$BASE" 2>/dev/null
  ( cd "$REPO" && eval "$*" )
  git -C "$REPO" add -A >/dev/null
  git -C "$REPO" commit -qm "$msg"
  git -C "$REPO" rev-parse HEAD
}
push_main() {  # <sha> [remote-sha] -> branch-guard exit code
  printf 'refs/heads/main %s refs/heads/main %s\n' "$1" "${2:-$BASE}" | bash "$G" >/dev/null 2>&1
}
fixes() {  # <sha> -> fixes-guard exit code, judged against BASE
  printf 'refs/heads/main %s refs/heads/main %s\n' "$1" "$BASE" | bash "$F" >/dev/null 2>&1
}

# ── allowed on main ─────────────────────────────────────────────────────────
S="$(commit_on_base "guide edit" "printf 'Line two.\n' >> docs/guides/a.md")"
push_main "$S" && ok "an edited docs/ page may land on main" || bad "an edited docs/ page was refused on main"
fixes "$S" && ok "a docs-only push owes no fix note" || bad "a docs-only push was refused for want of a note"

S="$(commit_on_base "new guide" "printf '# B\n' > docs/guides/b.md")"
push_main "$S" && ok "a new docs/ page may land on main" || bad "a new docs/ page was refused on main"

S="$(commit_on_base "rule append" "printf '\n## Appended\n\nMore law.\n' >> RULES/99-a-rule.md")"
push_main "$S" && ok "an append to a rule may land on main" || bad "an append to a rule was refused on main"
fixes "$S" && bad "a rule change was let through with no fix note" || ok "a rule change still owes its fix note"

S="$(commit_on_base "rule append with note" "printf '\n## Appended\n' >> RULES/99-a-rule.md; printf 'note\n' > docs/fixes/gates/unversioned-rule.md")"
push_main "$S" && ok "a rule append with its new fix note may land on main" || bad "a rule append with its fix note was refused"
fixes "$S" && ok "the rule change with its note passes the record gate" || bad "a rule change with its note was refused"

# ── refused on main ─────────────────────────────────────────────────────────
S="$(commit_on_base "rule rewrite" "printf '# Rule 99\n\nA new law.\n' > RULES/99-a-rule.md")"
push_main "$S" && bad "a rule REWRITE landed on main" || ok "a rule rewrite (deleted lines) is refused"

S="$(commit_on_base "code" "printf 'echo bye\n' >> apps/x/run.sh")"
push_main "$S" && bad "an app change landed on main" || ok "an app change is refused"
fixes "$S" && bad "a code change passed with no fix note" || ok "a code change still owes a fix note"

S="$(commit_on_base "mixed" "printf 'x\n' >> docs/guides/a.md; printf 'y\n' >> apps/x/run.sh")"
push_main "$S" && bad "a mixed docs+code push landed on main" || ok "a mixed docs+code push is refused"

S="$(commit_on_base "agents" "printf 'more\n' >> AGENTS.md")"
push_main "$S" && bad "an AGENTS.md change landed on main" || ok "AGENTS.md is not a document by the set"

S="$(commit_on_base "catalogue" "printf 'row2\n' >> docs/features/_catalogue/rows.md")"
push_main "$S" && bad "a woven catalogue fragment landed on main" || ok "a catalogue fragment is refused"

S="$(commit_on_base "fix note rewrite" "printf 'new\n' >> docs/fixes/gates/old-note.md")"
push_main "$S" && bad "a rewritten fix note landed on main" || ok "a modified fix note is refused"

S="$(commit_on_base "delete doc" "git rm -q docs/guides/a.md")"
push_main "$S" && bad "a document deletion landed on main" || ok "a deletion is refused"

S="$(commit_on_base "rename doc" "git mv docs/guides/a.md docs/guides/c.md")"
push_main "$S" && bad "a document rename landed on main" || ok "a rename is refused"

S="$(commit_on_base "txt" "printf 'x\n' > docs/guides/notes.txt")"
push_main "$S" && bad "a non-Markdown file under docs/ landed on main" || ok "a non-Markdown file under docs/ is refused"

# a force-push: the pushed commit is not a descendant of what main is now.
S="$(commit_on_base "doc A" "printf 'A\n' >> docs/guides/a.md")"
T="$(commit_on_base "doc B" "printf 'B\n' >> docs/guides/a.md")"
push_main "$T" "$S" && bad "a non-fast-forward rewrite of main was let through" || ok "a non-fast-forward is refused"

# creation of main (remote sha all zero) and deletion of main stay refused.
Z=0000000000000000000000000000000000000000
S="$(commit_on_base "doc" "printf 'z\n' >> docs/guides/a.md")"
push_main "$S" "$Z" && bad "creating main by push was allowed" || ok "creating main is refused"
printf '(delete) %s refs/heads/main %s\n' "$Z" "$BASE" | bash "$G" >/dev/null 2>&1 \
  && bad "deleting main was allowed" || ok "deleting main is refused"

# the --documents door answers the same question by hand.
S="$(commit_on_base "doc" "printf 'w\n' >> docs/guides/a.md")"
( cd "$REPO" && bash "$G" --documents "$BASE" "$S" >/dev/null 2>&1 ) \
  && ok "--documents says yes for a docs-only range" || bad "--documents refused a docs-only range"

printf '\n%s\n' "----------------------------------------"
if [ "$fail" = 0 ]; then printf 'branch-guard-documents.test.sh: all passed\n'; else printf 'branch-guard-documents.test.sh: FAILED\n' >&2; fi
exit "$fail"
