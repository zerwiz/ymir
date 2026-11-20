## docs · unversioned · 2026-10-23 — the note-taker said "appended" and wrote nothing

### Why

Four append operations through the `ymir_note` tool returned success — *"appended to
`<path>`"* — and left the file carrying **only a `---` separator and blank lines**. The
bodies were dropped silently: no error, no partial write, nothing in a queue. It was
discovered only when staging the home for a commit, where `git diff --cached --stat`
showed five added lines per file for sections that should have been forty.

The affected records were rewritten by hand with `cat >>` and read back: the masterplan's
account of the night, plan 118's corrections, and plans 14 and 15.

This is the same species as the fault the hall had that same evening — a panel that printed
`0` over a 401, a scheduler that reported "stopped" over a running loop. **A tool that says
it wrote, and did not, is indistinguishable from one that worked, until somebody looks.**
Rule 34's sentence covers it.

### What a fix looks like

An append must be verified by reading its own result back — at minimum that the file grew by
the body's length and that the heading is present — and must fail loudly when it did not. Until
then: append with `cat >> … <<'EOF'` and `grep` the heading, which is what the house's own
notes say they do.

### Files
- the four re-written documents under `hodd/` (home, not this tree)
- this note
