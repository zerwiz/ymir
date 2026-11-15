---
title: "Where a gate's words go"
status: "accepted"
owner: "the project's collaboration-kit owner"
updated: "2026-11-11"
---

# Where a gate's words go — the arm holder's window, and the project's orchestrator

**The fault this ends.** A gate printed its refusal at whoever typed `git commit` or `git push`. If that is the
operator, he reads a message meant for an agent; if it is an agent, it reads it once and forgets. The hand that
holds the lock and the arm — the one that could act on it — was never told.

**His words, 2026-11-08:** *"they answering me instead of the hand that holds the … arm — it needs to inject the
messages into the arm holder's chat window, also to the orchestrator that we have deployed per project."*

## The door

`scripts/notify-arm.sh <gate> <message…>` — installed with the kit, and called by all three hooks on every
refusal. It is also runnable by hand, and `--who` prints what it resolves and why.

```
notify-arm[5]{key,value}:
  "repo","the repository name, nothing more"
  "state","the house's state shelf (YMIR_STATE_DIR · $YMIR_HOME/state · ~/Documents/ymirhome/state)"
  "arm","live (a lease whose pid still exists) or none"
  "orchestrator","declared, or none"
```

## Three receivers, each resolved, never guessed

**1 · The arm holder.** One line appended to `<state>/.wake-queue` — the arm's own inbox, which the drain prints
as `WAKE KIT …` **in the arm holder's chat window**. This is the house's durable lane; it survives a restart and
it needs no pane gymnastics.

**2 · The estate.** Asked of the house's own door — `bin/agents/areas.sh estate <path>` — which resolves the
project from the repository's own path, so no id is guessed and no registry is restated. Its one line travels to
the arm holder with the refusal:

```
KIT Example-ControlTower · estate · areas: 18 · 5 held · 0 unproved · 0 waived · 0 na · 13 unheld (example-3)
```

Where the refusal **names an area** — `tenancy (unheld): apps/ct_core/lib/ct_core/domains/tenancy.ex` — a third
line carries the one command that fixes it:

```
KIT Example-ControlTower · remedy · tenancy is unheld — shape it, then apply it:
  bash bin/agents/areas.sh call example-3 tenancy
```

**3 · The project's orchestrator.** Declared in **one** place, and the first that answers wins:

- `orchestrator:` in the repository's `areas/agents.yaml` (a seat id, or an `https://` card address);
- `$YMIR_ORCHESTRATOR_CMD` — an explicit command, handed the notice line as its only argument.

A seat id is nudged through `brokk-send.sh`. A card address is **not** called: a card is an invitation to ask,
never a grant, and a notice is not a task. The door says so plainly instead of inventing a call.

**4 · Nobody declared.** The notice still travels to the arm, and its line records that nothing else was
declared. A silently undelivered notice is the fault this door exists to end.

## The four laws it holds

1. **It never breaks a git operation.** Every failure exits 0 and explains itself only under
   `KIT_NOTIFY_DEBUG=1`. (`KIT_NOTIFY_STRICT=1` turns a failed delivery into a refusal, for a house that wants
   proof of delivery.)
2. **No address leaks.** The line names the repository, the gate and the first line of the message — never a
   host, a port, a path of the house or a person (`RULES/39`).
3. **One notice per message.** An identical line already last in the queue is not appended twice, so
   `pre-commit` and `pre-push` firing together do not shout twice.
4. **No arm, no shout.** With no live lease the door is silent by construction: there is nobody to inject into.

## What is still owed

The **estate** line is answered by the house's own door for every registered project, so it is never missing. The
**orchestrator** is only as real as its declaration: no project declares one yet, so notices reach the arm and
record `orchestrator=none`. Naming it per project — a seat id, or the card address that answers — is one line in
that project's `areas/agents.yaml`.

## References

- `scripts/notify-arm.sh`, `docs/gates.md`
- `docs/headers.md` — the header and References format this document follows

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
