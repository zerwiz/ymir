# The project brief — "brief me on this project"

**What it is.** When you ask an AI coding tool for a brief on the project you are in, it runs one command and gets the
project's private bearings from your home: where its folder is, its where-we-are note, the open to-do lines that name
it, and what the newest daily log says about it. It works in any tool and any project in your registry, and only when
you ask.

## What you need

- Ymir, and your home with `hodd/identity/projects.yaml`.
- The project's entry there: `repo:` (owner/name) or `clones:`, a `seat:` folder in the home, and `aliases:` if people
  call it something shorter.
- Optionally a short `NOW.md` in that folder: where it stands, what waits on whom, where everything lives.

## Do it

    bin/records/project-brief.sh             # the project of the current directory
    bin/records/project-brief.sh <dir>       # another project's directory
    bin/records/project-brief.sh --self-test

Or just ask your tool: *"brief me on this project"* (the Sága skill, asset `project-brief.md`).

## Limits

- Read-only; it changes nothing.
- It never runs by itself at session start.
- It shows the first 40 lines of the note, up to 12 to-do lines and the last 10 daily lines that name the project.

## If it does not work

- *"this directory is not in hodd/identity/projects.yaml"* — add the project's entry.
- *"home folder: none"* — add `seat:` to the entry.
- *"no home resolved"* — set `YMIR_HOME`.

## CHANGE LOG

- **2026-11-11** — first written.
