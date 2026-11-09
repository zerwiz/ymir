# He answers, and he knows what is happening

**Date:** 2026-11-09 · **Component:** assistant · **Status:** built; his gate unchanged by design

## Why

The Allfather's own words, this day: *"we need to make a plan for skirnir … its to blocked … it should be
my assistant"*, and then, about the mind: *"give Skírnir a mind that answers, without ever weakening his
gate"*. Plan 227 §1 had already measured the fault by talking to him:

```
$ python3 systems/skirnir/services/skirnir.py --tier owner --channel dm --sender owner --text "status"
{"answer": "WaveTerm Troubleshooting Guide — status Open.", "intent": "fact:home-doc-…-waveterm-troubleshooting-md"}
```

Asked for `status` he returned a **document title** matched by keyword. So his "model is too small" was
never the problem: `_rail` existed and the answer path never reached it. Two causes, both measured here:

- **no mouth was configured on a hand-run.** `mouth = model or $SKIRNIR_MODEL or ""` — the deployed unit
  set the env, a person at a shell did not, so the same binary answered richly on Telegram and echoed at
  the console.
- **a matched fact was never phrased.** Even with a mouth, the `fact:` branch set `reply = claim` and
  moved on; only an unmatched question reached the model, over the whole public digest.

## What was built

1. **The answer path.** For a matched fact the mouth receives **only the matched facts** — filtered by
   the existing `model_context` (model-safe classes) and then again by tier, so anyone but the Allfather
   hears `public` only. A `verbatim` fact, an `internal` fact and every NDA class are never sent.
2. **A fallback that says what it is.** When no mouth composes, the matched claim is spoken *as a
   reference*: *"… That is the reference I hold — I could not put it in my own words just now."* For
   material the record forbids paraphrase the sentence is the true one instead — *"Those are the record's
   own words — not mine to put in my own mouth."*
3. **A limit named, not hidden.** A colleague who asks about a non-public fact is told which door is
   shut (*"it is the house's internal record — that belongs to him, not to the room"*) instead of
   "I don't know", which would be a lie when the fact was found.
4. **The database** (plan 227 §S1.5). `systems/skirnir/services/assistant-brief.sh` — four verbs
   (`refresh` · `show [date]` · `recall <question>` · `status`) — compiles the plan ledger, the errands in
   flight and dead, the week's merged PRs, the decisions and the recent runes into ONE dated briefing at
   `hodd/memory/assistant/briefing/<date>.md`, appended, and observes it into the one well under the
   stable tag `assistant-briefing`. `bin/assistant/assistant-brief.sh` is the shim at the path its
   siblings use.
5. **Configuration, not literals** (Rule 07). The mouth is `--model` → `SKIRNIR_MODEL` →
   `$YMIR_HOME/config/skirnir.yaml`'s `model:`; the URL adds that file's `model_url:`; the rail key is
   `SKIRNIR_MODEL_KEY` → the vault (`LLAMA_SWAP_API_KEY` by name) → the seat's own pi registry. The old
   `llama-swap` provider name was hardcoded in `_rail`.
6. **The Telegram faults.** `rate limited (too fast)` dropped the message with a stderr line and no
   sentence — the chat is now told to wait, once per two minutes. A send that hit a 429 was lost because
   the offset had already moved — it now honours `retry_after` and retries. Any exception inside one
   update escaped `main()`, so a poison message became a crash loop (restart → replay → crash) — each
   update is now wrapped, the offset still advances, and the fault is printed. A failed poll is printed
   and counted, and the offset/heartbeat write can no longer kill the poller.

## What was NOT touched

The gate. `gate()` (no URL, no link, no image, no code block, the canaries), the intent allowlist, the
audience filter, `say_unknown`, the escalation road, the sends — all unchanged, and they still run
**before** any model call and again on the model's words. A stranger still cannot reach `_rail`:
`tier in MODEL_TIERS` excludes him, and `compose_fact()` re-checks it, because a guard that lives in one
place is a guard that can be removed from one place.

## Proof

```
$ python3 -m unittest discover -s systems/skirnir/services -p 'test_*.py'
Ran 45 tests … OK                     # test_mind (20) · test_brief (10) · test_telegram (7) + the two existing files

$ bash systems/skirnir/services/walls-test.sh   # 33 assertions, diffed against origin/main: IDENTICAL
9 failures on main, the same 9 here — none of them the gate (four are the suite's own bugs:
`ENGINE` is not exported and `skip` is undefined, so those assertions fail on the shell, not the wall)

$ systems/skirnir/services/assistant-brief.sh refresh
briefing[1]… "refresh","2026-11-09","hodd/memory/assistant/briefing/2026-11-09.md",1,130,64,1,22,1,3,"stored",…

$ skirnir.py --tier owner --text "what did we decide about the microphone"
"From my briefing of 2026-11-09: #599 · plan 224 — «the voice host refuses to take the mic from a live
 call …» · merged 2026-11-09 · fix(voice,snotra,runtime): the microphone is never taken…"

$ skirnir.py --tier stranger --text "update your database"     # 0.37 s, no model call
"I can't send, book or change anything — I'm a mouth, not a hand. …"
```

## Owed

- one row in the LIVE home's `$YMIR_HOME/config/cron.yaml` for the 05:40 nightly refresh (the template in
  this tree carries it; the home is the operator's, and this errand may not write outside its worktree);
- the rest of plan 227 — the meeting door, the people register, the write tools (S2–S5). This change is
  S1 and S1.5 only: a mind that answers, and a database that is current.

## One register reads "decide"

`bin/gates/capabilities.sh` lists `bin/assistant/assistant-brief.sh` as *"uncalled — unnamed and
untested"*. It is both: the cron row at 05:40 and the phrase `update skirnirs database` call it, and
`systems/skirnir/services/test_brief.py` tests it. The register only reads NAMES out of
`.agents/skills/*/{SKILL.md,assets/*.md}` and the repo root `AGENTS.md`, and Skírnir has no skill on that
shelf — the gap is the shelf's, not this door's. Recorded rather than papered over: a register that says
"decide" about a called, tested door is telling the truth about its own reach.
