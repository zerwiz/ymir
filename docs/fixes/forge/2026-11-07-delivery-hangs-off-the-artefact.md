## forge · unversioned · 2026-11-07 — delivery hangs off the ARTEFACT, and the queue the arm reads is the queue notify writes

The Allfather, after watching a judge and a smith both finish in silence: **"THIS MUST ALLWAYS
FUCKING HAPPEND."** Two faults sat under that sentence, and both were measurable.

### F1 · Two wake queues, and notify wrote the one nothing reads

`bin/notify/send.sh` built its arm path as `hodd/state/.wake-queue`, while the arm (`syn-watch`) and
`bin/seat/lock-ask.sh` drain `<home>/state/.wake-queue`. Two files, both real, both non-empty:

```
queues[2]{path,size}:
  "hodd/state/.wake-queue","1.3 KB — what notify wrote, read by nobody"
  "state/.wake-queue","6.2 KB — what the arm drains, holding asks and no verdicts"
```

So every "delivered to the arm" notification went into a side file. That is plan 203 §19 again — a
local fact **restated** instead of resolved — inside the delivery path itself. `notify` now resolves
the state dir through `hoard-lib` (`hoard_state_dir`), the same door the arm uses. **Proved:**

```
notify[1]{decision,source,severity,rune,arm,desktop,pocket,telegram}:
  "send","review","HIGH","1","1","0","1","0"        ← arm=1, and the queue grew 25 → 26
```

### F2 · A seat is *told* to speak, and a model may forget

The charter and both errand briefs now carry the mouth (`notify` on every verdict, `herdr agent
prompt <peer>` to hand work back). But measured twice, that is not a guarantee: after asking a judge
and then a smith to run the notify in one exact line, **the queue did not move either time.**

So delivery no longer depends on the seat. `bin/forge/verdict-watch.sh` fingerprints every report in
`state/eindri-reports/`, and a NEW or CHANGED file is delivered through the hotline — Runes, the arm's
queue, the pocket; Telegram when a room is configured. `review-watch` calls it on **every pass**, so
the ten-minute timer carries it. **Proved:** one pass delivered six existing reports (`6 watched · 6
delivered · 0 failed`), and a second pass delivered nothing twice.

| file | change |
|---|---|
| `bin/notify/send.sh` | the arm queue resolved (`hoard_state_dir`), never restated |
| `bin/forge/verdict-watch.sh` (new) | watches the reports, delivers the new/changed ones, marks each fingerprint |
| `bin/forge/review-watch.sh` | runs `verdict-watch` on every pass, and says so loudly if it fails |
| `bin/forge/review-seat.sh` · `repair-errand.md` · `conflict-errand.md` | the mouth and the peer road, written where each figure reads it |

### Still unconfigured, and named rather than hidden

The **human road** is not built: `@YmirHeartBot` has never been `/start`'ed (`getUpdates` = 0) so it
cannot speak first, and the mail desk has no account row. Until one of those exists, a verdict reaches
the arm's queue and the Runes ledger — which the operator's sessions read — and stops there.

## CHANGE LOG

- 2026-11-07 · notify resolved the arm's own queue; verdict-watch delivers the artefact, and the loop
  calls it every pass. Six reports delivered in one pass; the human road still needs one `/start`.
