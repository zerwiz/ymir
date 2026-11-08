# A model that loops is a fault — read from the industry, then measured here

**2026-11-08 · component: agents**

## The fault the Allfather saw

Reading the `domain:tenancy` pane: a seated keeper emitting malformed tool-call markup in a loop —
`<||DSML||>` again and again, the same sentence repeated, 86k tokens up, three percent of a window burnt
on nothing. And nothing in the house noticed. He asked the right question next: *"are that alos look ing
for other types of spams? read on line for best practices"*.

## Why nothing noticed — the guard inventory, read

Forty-three tree wards sit in `bin/gates/guards/` — secrets, private data, the vault, the confidential
session, paths and legality, packaging, cron, features, weave, inventory, registers, rules compliance,
docs claims, language, dead code, mocks, subsystem docs, fleet version, identity, people, permissions,
public data, grants, git clobber, branch, pr-ship, runtime pins, defaults, areas.

**Every one of them judges the TREE.** The nearest is `model-rows-guard.sh`, which judges the catalog's
rows — not a running agent's mouth. Nothing watched what a seated model was actually saying.

## The detector set — read, not invented

Read 2026-11-08: Praison's doom-loop detection, pydantic's `DetectLoops`, OpenRouter's `doomLoop`
(`generic_repeat`, `poll_no_progress`, `ping_pong`), RunGuard's fingerprinted sliding window, CoderClaw's
tool-loop detection, LoopGuard's budget fuses and cost velocity, weft's `UsageLimit`/`MaxSteps`, and the
REGS-N n-gram repetition ratio (Pegasus' `repetition_scorer`, `ai_tokenopt`'s streaming `RepetitionDetector`).
The industry's own rule, which this guard now obeys: **one signal is a suspicion; several together are a
loop.**

```
detectors[6]{id,what it detects,where it came from}:
  "generic_repeat","the same tool call with identical arguments N times","Praison · CoderClaw · weft"
  "poll_no_progress","the same call AND the same result, repeatedly","Praison"
  "ping_pong","two states bouncing A → B → A → B","Praison · RunGuard's window"
  "error_echo","the same error line repeated","agentop's thrash · LoopGuard"
  "ngram","repeated 3-grams as a RATIO of all 3-grams ≥ 35%","REGS-N · Pegasus · ai_tokenopt"
  "runaway_spend","cost ≥ \\$2 in one seat, or context ≥ 80% full","LoopGuard · weft UsageLimit"
```

Plus the original two, which are this house's own: **malformed tool markup** (a model that cannot call
tools retries forever) and **a line repeated N times** (a loop, whatever its content).

## What it does with a finding

It names the pane, the symptom with its count, the spend and the context; injects **one** line into the
arm holder's chat (`eindri-notify.sh`); carves a rune; and stops nothing unless given `--stop` — a stop is
the holder's call, and the house has paid for a guard that decided for a person.

## Swept globally, because it is not one pane's problem

`--global [--hours N]` sweeps every pane in **every workspace** (a live alarm) and every session file on
disk by mtime (a **ledger** — the fault outlives the pane), including the opencode store when present.

Measured the same hour: **six session files on this machine carry the malformed-markup signature, the
oldest dated 2026-09-17.** Two months of the same fault, in different seats, unnoticed. That is the answer
to his question — it happens in more places than one pane, and now it reports.

## Three faults in the guard itself, found by running it

It accused the arm holder's own pane (the guard's own words live in that transcript) — it now resolves
`who.sh --me` and skips it. It treated a single mention as a loop — a loop is three. And the first detector
pass counted *every* tool-ish line as a repeat, so the first version would have cried wolf on any busy seat:
the count is now the largest single repeated group, not the total. **Known limit, recorded:** the holder's
own session file still matches once the guard is discussed in it; the file sweep says so rather than
pretending to be clean.

## Shipped

An hourly Nornir row in `.agents/config/cron.yaml.example` (`@hourly:47 bin/agents/spam-guard.sh`), so
every installation looks at every seat's mouth and tells the arm holder.

## CHANGE LOG

- **2026-11-08** — Opened with the fault, the inventory, the six detectors read from the industry, the
  global sweep, the two months of evidence, and the three faults found in the guard itself.
