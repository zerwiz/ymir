# Choose the models your judges and coders run

You decide which model each job in the house runs on, and whether its worker runs without asking.
You do it in one file in your home, per job, and per machine if you wish. Nothing is hardcoded.

## What it is

A **role** is a job: `judge` (reviews and merges every pull request), `coder` (builds the change),
`scout` (reads and reports) and `helm` (the session that steers the fleet).

For each role your home lists **choices**, in order of preference. A choice is `harness:model`.
The first choice this machine can serve wins. A choice it cannot serve is **skipped and named**,
never swapped for something else without telling you.

| Harness | What the model name is | Who says whether it can be served |
|---|---|---|
| `claude` | `opus`, `sonnet`, `haiku`, or a full Claude name | Claude's allow-list (`bin/model/model-allow.sh`) |
| `pi` | `provider/model`, hosted or local | this machine's catalogue (`bin/model/catalog.sh`) |
| `opencode` | `provider/model` of an opencode hosted model | your allow-list |

## What you need

- A home with `config/agents.yaml` (run `bin/fleet/agents-config.sh init` to seed it from the template).
- The models you name must be on your allow-list and, for `pi`, in the machine's catalogue.

## Set it up

Add a `roles:` block to `config/agents.yaml`. The template `config/agents.yaml.example` carries a working one.

```yaml
roles:
  judge: [claude:opus, pi:opencode-go/deepseek-v4.1-flash]
  coder:
    choose: [claude:sonnet, pi:opencode-go/deepseek-v4.1-flash]
    yolo: on
  scout: [pi:opencode-go/deepseek-v4.1-flash]
  helm:  [claude:opus]
```

For one machine only, put the same keys in `config/agents.<hostname>.yaml`. A role named there replaces
that role's list (and its `yolo`) on that machine. Roles it does not name keep the fleet file's.

Ready-made files for a machine with only local models, only hosted models, or both are in
[`docs/reference/role-models.md`](../reference/role-models.md).

## The commands

```bash
bin/model/role-model.sh coder --explain
```

Prints the harness and model the coder would get here, which choice won, and every choice it skipped and why.

```bash
bin/model/role-model.sh --check
```

Resolves every role. Use it after you edit the file.

```bash
bin/model/role-model.sh judge --harness pi --model opencode-go/deepseek-v4.1-flash
```

An explicit pair on the command line always wins over the list, for that one run.

Every spawn goes through this one resolver: `bin/agents/einherjar-spawn.sh`, the errand door
(`ymir_errand start`), the review spine (`bin/agents/eindri-review-spawn.sh`), the review loop and the work loop.

## Yolo: workers that run without asking

`yolo: on` means the worker runs unattended and never stops at a permission prompt.

| Harness | `yolo: on` | `yolo: off` |
|---|---|---|
| `claude` | permission mode `bypassPermissions` | permission mode `dontAsk`: only the allow list runs, anything else is denied |
| `pi`, `opencode` | allow-all | allow-all (they have no allow list to tighten) |

> [!IMPORTANT]
> `yolo: on` removes the prompts, not the fence. On Claude every **deny** rule in the profile still holds:
> no merging, no push to `main`, no token leaving the machine. The judge alone merges, through its door.

The house default is **on for `coder`** (the judge, not the coder, answers for a merge) and **off for every other role**.
Change it per role with `yolo:` in the role, or for all roles without their own with `yolo: {default: on}`.
The order of authority is: `--yolo on|off` on the command, your machine file, your fleet file, the house default.

Every spawn prints the posture that took effect, for example:

```text
posture fix-login role=coder harness=claude model=sonnet: yolo on: claude permission mode bypassPermissions, no prompts; every deny rule in the profile still holds · role coder: choice 1 of the home's list (claude:sonnet)
```

## Limits

- A role with no `roles:` entry keeps the older chain (the `agents:` rows and `default_model`), unchanged.
- A role whose list has no servable choice is refused. The error names each choice and why it failed.
- The list picks the harness and model only. The figure card, the books to read first and the plans a PR claims
  are handed over the same way for every choice.

## If it does not work

| You see | Do this |
|---|---|
| `no choice for role 'coder' can be served` | run `bin/model/role-model.sh coder --explain` and fix or add a choice |
| `the operator's allow-list refuses it` | add the model with `bin/model/model-allow.sh` or pick another |
| `this seat's catalogue does not list it` | the model is not served here; run `bin/model/catalog.sh` and choose a listed one |
| `declares no choices for role` | add that role under `roles:` |

## CHANGE LOG

- 2026-11-21 — added with the role resolver, real yolo and the shared judge/coder kit. Fix notes: `docs/fixes/model/2026-11-21-models-are-chosen-per-role.md`, `docs/fixes/seat/2026-11-21-yolo-is-real.md`.
