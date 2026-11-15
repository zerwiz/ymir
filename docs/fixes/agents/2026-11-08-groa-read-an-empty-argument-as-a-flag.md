# Gróa read an empty argument as a flag — and reported a hard failure while doing the whole job

**2026-11-08 · component: agents**

## What was wrong

`bin/agents/groa-update.sh` exited **2** every time a harness asked it to *update* rather than *check*.
Both surfaces (`.pi/extensions/eir.ts`, `.agents/harness/opencode/plugins/ymir-tools.ts`) passed
`[""]` for update — an empty string standing in for "no flag" — and the door's flag parser read `""` as
an unknown flag, printed `unknown flag`, and exited 2.

So the tool said *"Gróa did not finish cleanly (exit 2). The seat may be partly renewed — read the
output before running it again"* while Gróa had in fact done the entire renewal: fast-forward check,
seat identity, the codex plugin, the loaders, the harness extensions, the arm hook. The only thing
wrong was the exit code, and that is the worst kind of wrong: a green described as a red teaches a hand
to distrust the door.

## What was fixed

**At the door, first**, because the fleet carries installed harness copies that will not change until
each machine updates: an empty argument is now skipped rather than refused. A door only one caller
understands is not a door for the fleet (RULES/25).

**At both callers** second: update passes no argument at all rather than an empty one.

## Verified

```
bash bin/agents/groa-update.sh ""   → exit 0   (the old failure, now tolerated)
ymir_update(mode=update)           → the full report, no "did not finish cleanly"
```

The run it now reports: `fresh-base FRESH` · this home `skipped — on branch yggdrasil/areas-of-a-project`
(a worktree on a feature branch is a legitimate skip, and it says so rather than calling it a fault) ·
seat identity `nidavellir · Hávi` · codex plugin refreshed · loaders and harness extensions refreshed ·
arm hook re-seated · `eir: 7 surfaces need mending`.

## What it means for another user

Their installed extension still passes `""`; the door now tolerates it, so their update stops reporting
a false failure the moment this reaches their tree — and their own next update refreshes the callers too.

## CHANGE LOG

- **2026-11-08** — Opened with the fault, the door-side fix, and both callers.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
