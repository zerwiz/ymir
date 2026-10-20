# The council of models

> **Status:** shipped 2026-10-20 as the first slice (plan 92). Two to five models sit on one
> question, debate it, and hand down one verdict. It writes nothing — recording is yours.

## What it is

A **council**: several different models, each with its own remit, answering one question; then a
debate round where each seat reads the others and may change its mind; then an arbiter that merges
the answers into one decision **and keeps the disagreements visible**.

Lögrétta was the law council of the Althing — the assembly that hears a case, argues it, and hands
down one judgement. This is that council, for models.

## What you need

- **pi** on `PATH` (the seats are clean-room `pi` children — that is how two seats are two models).
- **A stack file** at `$YMIR_HOME/config/logretta-stack.yaml`. Copy the template:

  ```sh
  cp <repo>/config/logretta-stack.example.yaml "$YMIR_HOME/config/logretta-stack.yaml"
  ```

  Two to five slots; each slot is a `name`, a `model` (a fully-qualified `provider/id` exactly as
  pi serves it), a `lens`, and a `rail` (`local` · `fleet` · `hosted`).
- Models that pi can actually reach. `bin/seat/valknut-load.sh --check` proves the extension is
  deployed; `logretta_stack` (the tool) proves the stack is valid.

## The commands

Inside a pi session:

| tool | what it does |
|---|---|
| `logretta_stack` | validate the roster, print it, and print the honest queue |
| `logretta_sit` | sit a council on one question: `{ topic, recall?, rounds? }` |

From a shell, the same thing without a session:

```sh
LOGRETTA_STACK=~/.cache/logretta/stack-live.yaml node -e '
const {default:make}=await import("./.pi/extensions/logretta/index.ts");
const tools=new Map(); make({registerTool:t=>tools.set(t.name,t)});
console.log((await tools.get("logretta_sit").execute("1",{topic:"your question"},null,null,{cwd:process.cwd()})).content[0].text);
'
```

## The lenses

A seat is a **remit**, not just a model. Six ship today, and a custom name gets its own brief:

| lens | judges |
|---|---|
| `architect` | shape, seams, ownership, the expensive-to-reverse decision |
| `security` | the threat model, the door opened, the silent failure |
| `cost` | wall-clock, tokens, VRAM, and the recurring bill |
| `skeptic` | the unstated assumption, the first failure, what would prove it wrong |
| `operator` | the commands, the failure messages, what the human must remember |
| `recon` | what is measured, what is assumed, what must be read first |

Every seat receives the same **charter** (advise don't act; argue from your remit; be concrete;
separate knowledge from assumption; you may refuse) and every round has an **output contract**
(`POSITION / BECAUSE / THE HARD PART / WHAT WOULD CHANGE MY MIND`), so a missing section is
visible instead of hidden in prose.

## Limits — read these

- **Nothing is written.** No file, no code, no plan. The verdict is returned to you; record it with
  `ymir_note`, `ymir_plan`, or a Skuld ticket.
- **Every seat is read-only and sandboxed by its own flags**: `--tools read,grep,find,ls`,
  `--no-extensions`, `--no-session`. No seat can write, edit, or run a shell command.
- **Local seats speak in turn.** On a rail started with `--models-max 1` (heimdall does), only one
  local model is resident, so each local seat waits for the last to unload. Hosted seats run in
  parallel; the queue line says which is which **before** you spend anything.
- **A budget line per sitting** (`max_total_chars`) stops the council loudly rather than quietly
  spending more. `timeout_seconds` is per seat.
- **Vault content must run local-only.** Nothing from the vault may reach a hosted model
  (Rule 15). A stack whose vault runs mix `local` and `hosted` rails is your error, not the tool's.

## If it does not work

| symptom | cause | remedy |
|---|---|---|
| `no stack at …` | no stack file in the home | copy `config/logretta-stack.example.yaml` to `$YMIR_HOME/config/logretta-stack.yaml` |
| `the stack is invalid: unknown key …` | a typo in the stack | the message names the line and the known keys |
| every seat `FAILED: … exit 127` | `pi` not on `PATH` for the child | run from a normal session, or set `LOGRETTA_PI` |
| every seat `FAILED: model not found` | the id is not what the provider serves | ask the rail: `curl $BASE/v1/models` with the key, and copy the exact id |
| one seat `FAILED: timed out` | a local load slower than `timeout_seconds` | raise it for that stack, or seat a smaller model |
| `BUDGET` in the output | `max_total_chars` reached | raise it deliberately, or ask a narrower question |
