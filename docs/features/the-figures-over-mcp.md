# The figures over the MCP — Ymir's agents in any project, copied into none

## What it is

Ymir's figures (the judge Forseti, the coder Sindri, the scout Kvasir, Huginn and the rest) are served by the Ymir MCP.
A project that connects the MCP has them. The project's repository carries none of them, only its own craft.

| The MCP offers | What it carries |
|---|---|
| **prompts** | one per figure: its card and laws |
| **resources** | skills, listed small and read on need: `ymir-skill://frame/<name>` for Ymir's, `ymir-skill://project/<name>` for the repository the session was opened in |
| **tool `ymir_figure(name, task, project)`** | the figure's kit for a task |
| **tool `ymir_research(question, project, plan)`** | Huginn's road: search, read the main content of the best page, keep the finding |

## The kit

`ymir_figure` returns, for one task:

- the figure's prompt;
- the skills to read, chosen by the task's words and paths, from Ymir's frame and from the project's own `.agents/skills`;
- the tools the figure may use (a figure that cannot edit gets the reading doors and the Veil);
- the project's `RULES/` names and its `OUTCOMES.md`;
- the well's top episodes for the task.

A skill the task does not touch is not listed. A project is the `project` path you pass, else the git repository the session
was opened in.

## The commands

```
ymir_figure  name=forseti  task="review the packaging of the exporter"
ymir_research  question="how does X handle Y"  plan=358
```

`ymir_research` reads Firecrawl's address and key from the environment or the home's secrets (`FIRECRAWL_API_URL`,
`FIRECRAWL_API_KEY`), keeps the result with `bin/records/library.sh research keep` (source, practice, the plan that uses it),
and answers in a few lines. A question nothing answers is kept as a negative result.

## The register of doors

`bin/mcp/doors.yaml` lists every door that must have an MCP tool. `bin/gates/guards/mcp-parity-guard.sh` fails when a row
names a tool the server does not register. Add the row in the same change that builds the door.

## Limits

- The MCP SDK must be installed for the user (`python3 -m pip install --user mcp`).
- Resources are read when the server starts: a project skill added later shows after the session reconnects, and
  `ymir_figure` always reads the current shelf.

## If it does not work

- `python3 bin/mcp/ymir-mcp.py --selftest` prints the doors, prompts and resources it serves.
- `python3 bin/mcp/tests/test_figures.py` proves it from a temporary repository that has its own skill, and checks that no
  Ymir file is written into that repository.

## CHANGE LOG

- 2026-11-22 — opened (plan 358).
