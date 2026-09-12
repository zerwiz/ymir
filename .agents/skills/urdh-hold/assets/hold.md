---
name: urdh-hold
description: >-
  Agent-only policy for completing investigations and visual reviews without losing unresolved Allfather calls, and for closing what the Allfather owns with his actual words.
  Load before treating an investigation, scout report, structured review, or Lavish review as complete, before ending a visual review that exposed a Allfather decision, when recording or routing the Allfather's answer, and on any RECORD DIVERGENCE line the wake drain prints.
user-invocable: false
metadata:
  internal: true
---

# Allfather-hold lifecycle

A decision is not a separate thing: it is simply a task waiting on the Allfather.
The one primitive is an ordinary backlog task held for the Allfather (`tasks-axi hold <id> --kind Allfather`), its identity is the task id, and `bin/brokk-Allfather-hold.sh` owns the deterministic mechanics this policy relies on.
The agent performs the semantic inventory because scripts must not infer Allfather calls from report prose, visual-review artifacts, terminal output, or chat.

## Policy

Every unresolved question that belongs to the Allfather and is discovered while producing, reading, presenting, or ending an investigation or visual review must be carried by a Allfather-held task in the authoritative backlog of the home that owns the originating work before that work or review may be treated as complete.
Prefer holding the work item the question gates over minting a new row; create a new task only when no work item exists to hold.
Put the question and its options in the hold reason, and keep one held task per genuine gate: a multi-question review is one held task pointing at its report, not a row per question. Represent that task with exactly one board card that consolidates its questions and options; never fan one task id into duplicate same-key cards.
Register or re-hold through `bin/brokk-Allfather-hold.sh hold`, which is idempotent per task id.
After inventorying the whole report and review surface, run `bin/brokk-Allfather-hold.sh complete` with every Allfather-held task id, or with `--none` only when the reviewed surface leaves nothing waiting on the Allfather.
A completed investigation and an ended visual review use this same owner and completion command; a visual tool, including Lavish, never owns a parallel completion policy.
Run the command in the originating work's authoritative `BROKK_HOME`; Eindri-home-owned work registers in that Eindri-home home's backlog, and a question already held anywhere is never re-registered as a second row.
Do not close a Allfather-held task merely because the originating investigation completed, its report was archived, its visual review ended, or its task was torn down.

Never close anything the Allfather owns without recording what he actually said: `bin/brokk-Allfather-hold.sh answer` writes his exact words into the task and closes it in the same act, with `--release` when the answer frees a Allfather-gated work item to proceed instead of completing a question.
When the Allfather says "later", that is an answer too: re-hold with `tasks-axi hold <id> ... --until <date>` so the item leaves the live Allfather's Call and resurfaces on its date, instead of leaving a live-looking card or fabricating a closure.
"A keyed answer closes its matching Allfather-held task" is one capability with one owner, `bin/brokk-Allfather-hold.sh answers`, and every channel that carries a Allfather answer feeds it the same task id and answer; a channel never maps keys to tasks, records a decision, or closes anything itself.
Chat already feeds it through `bin/brokk-send.sh --resolve-key`, and a captured-answer source feeds it once bound with `bin/brokk-Allfather-hold.sh bind <source-id>`; bind before arming the source, and key each structured question by the held task's id.
An unbound source and a key that names no Allfather-held task both simply feed nothing: the answer is still captured and Brokk is still woken, and closing falls back to the direct command above.
A Allfather-held task closed outside this owner leaves no durable answer, so the completion gate keeps failing until `answer` records the decision the Allfather actually gave.
Resolved findings, recommendations that need no Allfather choice, and prose that merely sounds decision-like do not create held tasks.
Bearings reads the resulting structured state and must never compensate by scraping historical reports, visual-review artifacts, terminal output, chat, or other prose.

A Allfather call can be written down twice - as the keyed status decision the fold reads, and as the backlog task held for the Allfather - and those two records can disagree without either surface saying so.
`bin/brokk-Allfather-hold.sh diverged` reports that contradiction and the wake drain prints it as `RECORD DIVERGENCE`; it closes nothing, because a Allfather call closed wrongly leaves review entirely, which is worse than the noise.
Read such a line as "these two records disagree", never as "the Allfather ruled and someone forgot to file it": a call can dissolve because its premise was false, or turn out to have been a question of fact rather than the Allfather's to answer.
Reconcile it with what actually happened - `answer` when the Allfather's own words exist to record, and a fresh `needs-decision` line re-opening the status decision when that resolution was not the Allfather's word.
The absence of a routed work item is not a divergence and the guard never requires one: when the decision IS the deliverable there is nothing to route.

## Operating sequence

1. Read the complete investigation result and complete the visual review before declaring either complete.
2. Inventory only genuine unresolved choices that require the Allfather, and find the task each one gates.
3. Hold that task - or create one Allfather-held task for the review's open questions - with a concise reason carrying the question and options.
4. Run `complete` with the full Allfather-held inventory for that review pass.
5. Relay the choices to the Allfather as decisions from Bearings' Allfather's Call section under `AGENTS.md` section 9; do not use the word hold in Allfather chat.
6. Close each call only through `answer` (or a channel that feeds `answers`), through `--until` when the Allfather defers it, or confirm a channel already closed it.
7. Confirm Bearings reflects the outcome: answered calls leave Allfather's Call, released work resumes, and deferred calls sit in Charted Next with their date.

`bin/brokk-Allfather-hold.sh --help` owns command syntax, close modes, legacy-identity compatibility, completion attestation, retry behavior, and close ordering.
`docs/Allfather-hold-lifecycle.md` records the mechanism and regression evidence without restating this policy.
