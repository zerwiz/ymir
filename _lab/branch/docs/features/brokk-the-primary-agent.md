# Brokk — the primary agent

## What it is

**Brokk** is Ymir's primary agent — your counsellor in the main hall. It plans, steers,
reviews, and **dispatches** (see [Eindri](eindri-isolated-workers.md)); it does not build
alone in the main tree what a worker can forge in isolation. One machine has **one**
Brokk, bound so a second session cannot run beside it.

## What you need

- Ymir installed and raised (`ymir raise`).
- A harness on your PATH — **Pi**, OpenCode, Claude Code, Codex, or Cursor. Which one
  does the work is *your* choice, per agent.

## Do it

**Open a harness in the repo.** When it starts, **Sága** speaks before your first
turn: the seat is bound by **Gleipnir**, the model bridge is raised, the Nornir jobs
start, and the fleet context is injected. Nothing to configure.

**Or run one errand headless**, through the harness you chose:

```bash
bin/agents/agent-run.sh brokk "summarise the plan ledger and tell me what is owed"
```

**Choose the harness/model combination** — one YAML for all your agents:

```bash
bin/fleet/agents-config.sh show       # the current combination
bin/fleet/agents-config.sh roster     # role → figure → harness → model → tools
bin/fleet/agents-config.sh apply      # publish it into your harness configs
```

## The figures it can take

Brokk stays the primary; beside it Ymir seats specialists, each bound by
`bin/seat/valknut-load.sh`:

| Figure | Role |
|---|---|
| **Mímir** | planner — architecture, sequencing, risk |
| **Forseti** | reviewer — review, QA, acceptance (changes nothing) |
| **Snotra** | documenter — docs, changelogs |
| **Kvasir** | scout — reconnaissance (changes nothing) |

## Notes and limits

- **One primary per machine.** Brokk holds the session lock (Gleipnir); a second live
  primary is refused, not silently allowed.
- **Brokk counsels; Eindri forges.** Complex, isolated, or parallel work leaves as an
  Eindri on a worktree — [see that page](eindri-isolated-workers.md).
- **The seal is yours.** Brokk reviews and sews; it never merges. Merges are the
  Allfather's word (Rule 08).
- **Local or hosted.** Local models route through **Pi**; hosted ones through
  **OpenCode** — set per agent in `config/agents.yaml`.

## If it does not work

| What you see | What to do |
|---|---|
| Refused: a primary is already live | Another session holds the lock; end it, or use `bin/agents/eir-doctor.sh` to inspect the `lock` surface. |
| No digest on start | The session-start surface is not seated for that harness — `bin/seat/valknut-load.sh --check`, then re-bind. |
| The model never answers | The bridge/model rail is down — `bin/agents/eir-doctor.sh fix` (the `well`/`harness` surfaces), or check the rail. |
| Wrong harness runs | It is reading `config/agents.yaml`; change it with `bin/fleet/agents-config.sh` and `apply`. |
