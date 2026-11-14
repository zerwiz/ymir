# The hall ranks now — jev's policy, a measured judge, and no number without a door

**2026-11-09 · component: odrerir · `bin/seat/rank.sh` · `apps/hlidskjalf/server/index.ts` · `apps/odrerir/src/components/NearBoard.tsx` · `bin/model/jev-doors.sh`**

His word: *"fix it all then"*. This is the last thing the near loop could not do — it advertised
jev's Hype · Facts · Signal and computed none of them, because no door had ever been wired.

## How it is wired

- **`bin/seat/rank.sh` is transport, not judgement.** It posts one `score` question per jev
  category (hype · facts · signal) to a decision door and returns the engine's raw answers. It
  computes nothing, so there is no second copy of jev's thresholds in the tree.
- **The policy stays jev's.** The gate imports `rankHfs` from the vendored
  `apps/odrerir/src/vendor/jev/policy.ts` (MIT, unchanged) and turns answers into the
  `HfsResult` the card renders: `ranked`, `primary`, `scores`, `labels` at the 50 threshold,
  `suspectCombo`.
- **`POST /api/rank`** takes `{items:[{id,text}]}`, runs the transport with `cwd: ROOT`, applies
  the policy, memoises for two minutes, and returns `{door, ranked, failed}`.
- **The board asks, never assumes.** Once the operator's queue has arrived the near loop asks for
  scores once; a card carries `hfs` only if its item actually came back scored. The footer names
  the door that spoke, and when none did it says so and every card keeps **Not ranked yet**.

## Which judge — decided by measurement, not preference

All three Apache-2.0 doors were swept on the heart (20 timed requests each, one forward pass, no
tokens generated). On the canonical case — *charged twice, wants the second charge back → which
desk?*

```
door      options  median    decisions/sec  choice    conf   verdict
julia-1     3      127 ms      7.86         shipping  0.85   WRONG
laya        3      564 ms      1.77         billing   0.83   CORRECT
laya       12     1384 ms      0.72         billing   1.00   CORRECT
kev-4b      3     4724 ms      0.21         billing   0.99   CORRECT
kev-4b     12    13926 ms      0.07         billing   0.75   CORRECT
```

Kev-4B is the authority and would need 95 s to rank twenty cards; Julia-1 is the fastest and got
the money question wrong twice. **Laya is the only door that is both right and quick**, so
`rank.sh` prefers `laya`, falls to `kev-4b` as the escalation judge, and puts `julia-1` last,
with the reason written in its header. Laya is enabled on the heart; its residency did not move
the card (2952 MiB with it loaded).

## Also fixed here

`bin/model/jev-doors.sh` read a `host:` line with its trailing comment attached, so
`host: heimdall   # which machine…` became a hostname of `heimdall   # which machine…` and every
door fell back to `down`. Comments are stripped now. That is the third way this one register has
lied, and the third written down.

## Proved

- `POST /api/rank` on a scratch gate, engine under the unit's PATH-free env:
  `door: jev-laya`, `pending-0 → primary signal, scores {signal 25, facts 14, hype 36}`… a real
  `HfsResult`, not a placeholder.
- `bin/seat/tests/test_rank.sh` — **6 ok / 0 fail**: a dark door produces **no** scores and names
  the reason; empty and non-JSON input are refused; a live door returns all three category
  answers with legend and confidence. The live case says `skip` when no door answers.
- `tsc --noEmit` clean; `vite build` clean; galdr compliance green.

## Not done, named

`ledger.jsonl` still does not exist on this seat — the schema the errand named is not present, and
inventing a format to look complete would be worse than the gap. No online provider was driven
through the ranking path: the judge here is local, on the tailnet.

## CHANGE LOG

- **2026-11-09** — rank transport, a gate route applying jev's own policy, the near loop asking
  for scores and naming its judge, the host-comment fix in the door register, and the guard.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine (this seat). The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
