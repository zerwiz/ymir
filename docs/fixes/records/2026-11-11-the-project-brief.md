# Fix — a fresh session can find a project's private record, when asked

**What was wrong.** A session opened from zero in a project's repository — in Claude Code, Pi, OpenCode or Hermes —
had no road to that project's private record in the home: its plans, chats, board notes and what waits on whom. The
repository may not carry a private path (RULES/04), and a harness's own memory serves only that harness.

**What was done.** `bin/records/project-brief.sh` resolves the session's directory (git remote, or a recorded clone
path; a worktree resolves to its main checkout) to its entry in `hodd/identity/projects.yaml`, and prints the entry's
home folder (`seat:`) with its `NOW.md` (else `README.md`), the open to-do lines and the newest daily-log lines that
name it (by `id`, `name` and optional `aliases:`). It runs **only when asked** — the Sága skill's new asset
`project-brief.md` says when — never at session start, at the operator's word: *"only brief per project if asked to."*

**How it is proven.** `bin/records/project-brief.sh --self-test` — a fixture home and repository: the right entry is
found by remote, the note, an open to-do line, an alias match and a daily line are printed; a ticked to-do line, an
unrelated line and an unregistered directory are not.

## CHANGE LOG

- **2026-11-11** — written with the door.
