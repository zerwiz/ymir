## gate · unversioned · 2026-10-18 — a branch deletion owes no fix note

### Why

`fixes-guard.sh` refused a push whose only ref was a **branch deletion**. Git feeds
a delete as an all-zero local sha; the guard's loop skipped it, `head_sha` fell back
to `HEAD`, the range to the base was empty — and the push was refused with
*"refused — no fix note in this range"*. So `git push origin --delete <a merged
branch>` needed `--no-verify`.

Found in the act, twice in one evening: after #349 and after #350, deleting the
merged remote branch. The gate's own doctrine applies — *a gate that must be
routinely overridden is a gate nobody trusts*.

### Now

A push whose **every** ref is a delete is recognised as a deletion and allowed:
it delivers no content, so there is nothing to record. A delivery still owes its
fix note, and whether a deletion touches a **protected** branch remains
branch-guard's business (it blocks deleting `main`).

### Verified

`.agents/tests/fixes-guard-deletion.test.sh` → **3 passed, 0 failed**: a delivery
with no note is refused; a delivery carrying a note is allowed; a branch deletion
is allowed without a note. No test covered this path before.

### Files

- `bin/gates/guards/fixes-guard.sh`
- `.agents/tests/fixes-guard-deletion.test.sh` (new)
- `bin/README.md`, `.agents/assets/agents/capabilities.md` (regenerated)
