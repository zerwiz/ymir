# The keeper's desk — `domain.sh`, and the seat it is allowed to hold

**Date:** 2026-10-31 · **Component:** agents · **Status:** live; both keepers seated in herdr

## Why it exists

Plan 129 §23 said it plainly: *"without that door a keeper is a folder with a declaration, not an
office."* `bin/agents/domain.sh` is that door — `list · check · brief · call · status · stop`.

**The brief is generated, never hand-written.** It is composed from `systems/<domain>/domain.yaml`, the
keeper's figure in `.agents/agents/`, and the folder's own `AGENTS.md`, so a keeper cannot drift from the
system it keeps: change the declaration and the brief changes with it.

## The Allfather's correction, and why it mattered

*"if hes a pi agent he has to much power."* He is right, and plan 101 already said so in stronger words:
**"the model has NO tool calls at all. The orchestrator decides what may be fetched or sent, and the
credentials live only there."** A keeper seated as a full pi agent would hold bash, a pen, the vault path
and the network — the lethal trifecta, in the assistant whose whole design is that it cannot leak.

So a keeper's **seat is declared, not assumed**:

```yaml
seat:
  tools: none            # none | [read, grep, find, ls]
  mcp: none              # a door is a hand
  cwd: systems/<domain>/
  may_write: false
```

`seat.tools: none` becomes `pi --no-tools --no-mcp`; a list becomes `pi --tools <list> --no-mcp`. Skírnir
is a **brain with no hands** — he answers and drafts; his doors are scripts the house runs, not tools in
his pocket. Snotra reads her own folder (`read, grep, find, ls`) and no more: she curates records, she
does not edit code — a change to her doors is an errand with a brief.

## How a pane is seated (and the two wrong ways found today)

`pane run` alone hands the command a pipe, so pi answers once and exits — the pane looks seated and is
dead. The working shape is herdr 0.9's own:

```
herdr tab create --cwd <domain> --label domain:<n> --focus   → tab + root pane
herdr pane run <pane> "pi <seat args> --append-system-prompt <brief>"
herdr agent prompt <pane> "<opening>"
```

Proven: `domain.sh call skirnir` → `w38:t3 / w38:p3` (pi, idle, `systems/skirnir`), `domain.sh call snotra`
→ `w38:t4 / w38:p4` (pi, working, `systems/snotra`), and `domain.sh status` reports both panes.

## Owed

- a board per keeper and the well namespace `domain:<keeper>` (plan 129 P3): a seat with no queue and no
  memory is only half an office;
- `domain.sh stop` proven against both panes;
- the brief's `seat:` section should also be *enforced* for `--headless` runs by a check that the
  declaration was read at all (today it is read; a test would prove it).
