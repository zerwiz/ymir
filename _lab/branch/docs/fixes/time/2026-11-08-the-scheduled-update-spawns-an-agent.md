# The scheduled update spawns an agent, and the agent decides the road

**2026-11-08 · component: time · the Allfather's word**

## What he asked

*"add so all ymir installations runs an auto update nornir job on running groa to update latest from main"* — and
then the correction that makes it right: *"the update needs to spawn an pi agent to run the updates so its beeing
made in the way the users need based on information they have in ymir home"*, and: *"if herdr not available use a
regular terminal"*.

## What was forged

`bin/time/nornir-job-groa-update.sh` — a **spawner**, not a scripted fetch, with a row shipped in
`config/cron.yaml.example` so every installation gets it (`03:41` daily; `@hourly:41` is fine on a small fleet).

It reads the facts **from this machine's own home** and writes them into a generated brief — role, checkout,
branch, head, commits behind `main`, dirty paths, registered Eindri-homes, the resolved model, the opt-out — then
spawns one pi agent with that brief as its system prompt. The agent chooses the road from those facts and runs
**Gróa**, who is still the only door that moves anything: fast-forward when clean and on `main`, `--check` only
when dirty or on a branch, and an honest "offline" otherwise. Never force, never reset, never stash, never clean.

Three roads, in order, each named in the report:

```
roads[3]{road,when,what happens}:
  "herdr","herdr is present","a tab labelled nornir:auto-update is created and the runner SCRIPT is run in its pane — fire and forget, because the brief tells the agent to deliver its own line through eindri-notify.sh; a scheduled job that blocks ten minutes on a pane is a job found stuck at 03:41"
  "terminal","no herdr","`pi -p --model <resolved> -t bash,read --no-mcp` in the foreground, bounded at 420s — the documented print mode"
  "fallback","no pi, or no model resolved from the home","Gróa run directly, and the line says so, because a machine that cannot start a brain must still move"
```

## Four faults found by running it, not by reading it

1. **`printf %q` is not a spawn.** The first version typed an escaped command into the pane; the Allfather saw it
   sitting at the prompt with no agent. The invocation now goes in a script and the pane is told one unquoted
   word: `bash <runner>`.
2. **The harness default model was out of credit** — `403 Key limit exceeded … $1.02 of $1.00 used` — so the agent
   started, failed at the model, and looked like "no agent started". The model now resolves **from the home**
   (`YMIR_UPDATE_MODEL`, else the roster's model for `brokk`, else the catalog refuses it), which is exactly his
   words: the way the users need, from the information they have in ymir home.
3. **A refusal is named, not waited on.** A `403`/`401`/limit in the output now abandons the seat road immediately
   instead of polling for ten minutes for a line that will never come.
4. **The ROOT walker said `$RULES` instead of `$PWD/RULES`** — so the job resolved `/` and reported "no updater".

## Verified

```
bin/time/nornir-job-groa-update.sh --dry
  → role=dev branch=yggdrasil/areas-of-a-project head=ba5062d0 behind=4 dirty=2 homes=6
pi -p --model opencode-go/deepseek-v4.1-flash -t bash,read --no-mcp --append-system-prompt <brief> "<order>"
  → groa: check-only · ba5062d0 → ae623f62 · dirty tree (modified cron.yaml.example, untracked
    nornir-job-groa-update.sh) and not on main — yggdrasil/areas-of-a-project
```

That last line is the whole design working: an agent read this machine's own facts, refused to move a dirty tree on
a feature branch, named both reasons, and did not force anything.

## CHANGE LOG

- **2026-11-08** — Opened with the job, the shipped row, the three roads, and the four faults.
