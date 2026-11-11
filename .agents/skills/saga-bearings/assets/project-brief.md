# project-brief — "brief me on this project", on request only

**When:** the operator asks for a brief on the project the session is in — *"brief me on this project"*, *"where are
we with this repo"*, *"what is the state of <project>"*. **Never** at session start, and never unasked.

**Why it exists:** a repository may not carry a private path (RULES/04), so a fresh session in any harness — Claude
Code, Pi, OpenCode, Hermes — cannot find a project's private record (its plans, chats, board notes) from the repository
alone. The home's project registry can.

## Do it

    bin/records/project-brief.sh            # the project of the current directory
    bin/records/project-brief.sh <dir>      # the project <dir> belongs to
    bin/records/project-brief.sh --self-test

It finds the project in `$YMIR_HOME/hodd/identity/projects.yaml` by the directory's git remote (or a recorded clone
path; a worktree resolves to its main checkout), then prints:

1. the project's **home folder** (the entry's `seat:`) and its where-we-are note — `NOW.md`, else `README.md`;
2. the **open to-do lines** that name it (`hodd/life/personal/me/todo.md`);
3. the **newest daily-log lines** that name it.

Names are the entry's `id`, `name` and optional `aliases:` (for example a short name people actually write).

## Make a project briefable

In its registry entry: `repo:` (owner/name) or `clones:`, a `seat:` folder in the home, and `aliases:` if people call
it something shorter. In that folder, keep a short `NOW.md`: where it stands, what waits on whom, where everything
lives. A project without `seat:` says so; a directory not in the registry says so.

## Then

Read the files the brief points to before acting, and answer in prose. The brief is read-only; it changes nothing.

## CHANGE LOG

- **2026-11-11** — first written; on request only, at the operator's word (*"only brief per project if asked to"*).
