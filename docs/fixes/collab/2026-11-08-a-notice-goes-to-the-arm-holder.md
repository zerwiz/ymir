# A gate's words go to the arm holder — refusal, estate and remedy, injected into the window that can act

**2026-11-08 · component: collab · `bin/collab/kit/scripts/notify-arm.sh` · `bin/collab/kit/.githooks/{pre-commit,commit-msg,pre-push}` · `bin/collab/kit/docs/notices.md`**

## His word

*"they answering me instead of the hand that holds the … arm — it needs to inject the messages into the arm
holder's chat window, also to the orchestrator that we have deployed per project."*

## The fault this closes

Every gate printed its refusal at whoever happened to type `git commit` or `git push`. When that is the operator,
he reads a message meant for an agent; when it is an agent, it reads it once and forgets. **The hand holding the
lock and the arm — the only process that could act — was never told.** A gate that shouts in the wrong room is
indistinguishable from a gate nobody hears.

## What was built

```
built[4]{piece,what,proved}:
  "scripts/notify-arm.sh","the one door: a gate's message is appended to <state>/.wake-queue — the arm's own inbox, which the drain prints in the arm holder's WINDOW — and its receivers are resolved, never guessed","a live lease + a scratch repo: one KIT line per refusal arrived in the queue; `--who` prints repo, state, arm, orchestrator"
  "the estate receiver","asks the house's own door `bin/agents/areas.sh estate <path>` (path-resolved, no registry restated) and carries its line with the refusal: `areas: 18 · 5 held · 0 unproved · 0 waived · 0 na · 13 unheld (control-tower)`","measured on Inmost-ControlTower: 18 · 5 held · 13 unheld, matching `areas.sh estate` exactly"
  "the remedy line","where the refusal NAMES an area (`tenancy (unheld): <path>`), a third line names the one command: `bash bin/agents/areas.sh call <project> <area>`","the tenancy refusal produced exactly that line for control-tower"
  "the wiring","all three hooks call the door on every refusal — pr-guard, protected branch, fixes/referee/new-module/areas guards, checks, and commit-msg","commit-msg \"wip\" and a failing `check` each delivered a KIT line"
```

## The laws it holds

1. **It never breaks a git operation** — every failure exits 0, explains itself only under `KIT_NOTIFY_DEBUG=1`,
   and `KIT_NOTIFY_STRICT=1` turns a failed delivery into a refusal for a house that wants proof.
2. **No address leaks** — the line names the repository, the gate and the first line of the message; never a host,
   a port, a house path or a person (RULES/39).
3. **One notice per message** — an identical line already last in the queue is not appended twice.
4. **No arm, no shout** — with no live lease the door is silent by construction.

## The measurements

```
measured[4]{case,answer}:
  "live arm, areas refusal","3 lines queued: the refusal, the estate, the remedy"
  "live arm, commit-msg/checks refusal","1 line queued per refusal, printed to the terminal unchanged"
  "no arm","silent, exit 0 (say it only under KIT_NOTIFY_DEBUG=1)"
  "no arm + KIT_NOTIFY_STRICT=1","refused, exit 1, naming that no receiver took the notice"
```

## What is owed

The orchestrator receiver is only as real as its declaration (`orchestrator:` in a project's `areas/agents.yaml`,
or `YMIR_ORCHESTRATOR_CMD`). No project declares one today, so its notices record `orchestrator=none` rather than
pretending a delivery.

## CHANGE LOG

- **2026-11-08** — Carved. A gate's refusal now travels to the arm holder's window with the project's estate and
  the one command that fixes an unheld area, instead of shouting at whoever typed the command.
