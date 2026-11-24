# Sessions — every agent session on this machine, from every tool

`ymir sessions` reads the sessions your agent tools wrote — Claude Code, pi, Codex, Hermes and opencode — into one
local index. It turns them into each project's sessions, recurring failures, cost and **the next updates**. It works
completely on **one computer**: no heart, no second machine, no model needed.

## What you need

- Nothing beyond the tools you already use. The first scan reads the last 30 days (`--since DAYS` changes that).
- Optional: a judge model, see below. Without one everything else still works.

## The commands

| Command | What it does |
|---|---|
| `ymir sessions scan` | Reads only the new bytes of each session (byte offsets for files, time/id for the databases). |
| `ymir sessions list [--project P] [--tool T]` | Sessions, newest first, with project, spans, errors. |
| `ymir sessions decisions` | The same failure across tools, once, with every session it hit. |
| `ymir sessions updates [--project P]` | The next updates, each with its source session and a one-line action. |
| `ymir sessions alerts` | Task-failure rate, cost per session and judged quality, per project and per tool (7 days against the 7 before). |
| `ymir sessions judge` | The judge pass (below). |
| `ymir sessions brief` | The "what to update" lines for a morning brief. |
| `ymir sessions export --otlp URL` | Optional OTLP/HTTP export. Off unless you name a collector. |

Add `--fleet` to `list` to also fetch other seats' summaries. This machine asks and names the seat of every row; the
default never asks. Panels: **Sessions** (all tools), **Decisions** (failures across tools) and the **Projects** panel's
sessions column all read this machine's index.

## What is stored, and what is not

Spans follow the OpenTelemetry GenAI conventions, pinned to version 1.37.0 (they are still marked Development), with
`ymir.*` attributes for project, seat, tool and branch. Tokens, counts, a one-line error and the last prompt are kept.
**The raw transcript is never copied**; it stays where the tool wrote it.

Before anything is written, the house secret patterns, bearer tokens, e-mail addresses and the vault mount are masked.
A session whose working folder is inside the vault is counted only: no path, title, prompt, project or spans.
`--public-view` (and the panel's shared view) drops every session whose project is not marked public.

## The judge pass

It reads every session that errored, the most expensive ones and about a tenth of the rest, each once, and writes an
outcome, open threads and next updates. It uses **this machine's own judge profile**: set `YMIR_JUDGE_BASE_URL`,
`YMIR_JUDGE_MODEL` and `YMIR_JUDGE_KEY_ENV` (the name of the variable holding the key), or a `judge:` block in
`config/sessions.yaml` in your home. With no profile the judge is off and the index uses plain rules instead: a failure
that recurs in three or more sessions, or a session that ended on an error, becomes a next update.

## If it does not work

- *Empty panels:* run `ymir sessions scan` first.
- *A tool's sessions are missing:* the scan reads the tool's default folder under your home; a tool you moved is not found.
- *No next updates:* a project needs sessions that joined it. Sessions join by working folder or git remote, through
  the projects cloned on this machine (`ymir projects`).

## CHANGE LOG

- 2026-11-24 — added with plan 368.
