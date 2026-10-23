## agents · 2026-10-23 — Rule 34: a surface may not show what it did not receive

### Files
- `RULES/34-a-surface-may-not-show-what-it-did-not-receive.md` (new law)
- `RULES/README.md` (index row)
- `.agents/skills/galdr-ymirsystem/assets/smidja.md` (what the smithy owes the surface it ships)

### Why
Six measured lies in one evening, all the same defect wearing different clothes — a fallback that reports success:

| surface | showed | truth |
|---|---|---|
| Hlidskjalf · Snotra | 0 meetings · 0 decisions | 2 meetings, 24 decisions; the API had answered **401** |
| Hlidskjalf · Well | "bridge down" | `:4602/health` → **200**, 167 episodes |
| Hlidskjalf · Nornir | "STOPPED · 0/0" | runner alive, `jobs=29` |
| Hlidskjalf · Mánagandr | "the window is empty" | the read had failed |
| `snotra-harvest.sh speakers` | three WAV "tracks", exit 0 | the field named `pcm` is not PCM — noise (mean 16 354 vs speech 500–4 000) |
| a Snotra letter | "silence is provisional acceptance", due 2026-10-26 | no such policy; the record's own action is due 2026-10-24 |

### What the rule obliges
1 no figure without a receipt — `—` and a sentence on a refused read, never `0`;
2 no diagnosis from an absence — "down/stopped/empty" only from a successful read;
3 no inferring identity, state or policy — an unattributed quote stays null, an uncited sentence is not printed;
4 a fallback carries `cached`/`stale`/`unverified` on the same line as its value;
5 a generator proves its output or refuses it (card read back, audio decoded, letter ids cited);
6 it binds sandbox artefacts too.

### What it does not forbid
Clean skips (Rule 25), labelled inference (`candidate`, `inferred`), and caching — provided the surface says so.

### Owed
The Hlidskjalf panels still render `0` on a 401: Rule 34 is the law they must now be changed to keep. That is the
first task of the order agreed with the Allfather (plan 111, appendix 23:40 §6).

### Appendix (same day) — the ward learned `snotra`

`fixes-guard` refused this branch four times: the fix notes for the meeting doors live under
`docs/fixes/snotra/`, and the ward's component map knew no `snotra` — so a correct note covered nothing and every
push was refused. The map now names it (`bin/time/snotra/* → snotra`), the component list includes it, and the
`RULES/README.md` index declares 31 rules with the new row. A gate that must be overridden is a gate nobody trusts.

### Appendix 2 (same day) — the door index was a feedback loop, and that is why CI refused every push

`inventory --check` failed on every run — **and it failed on `main` too** (585 doors on disk, 557 rows in the
committed index). The generator read `bin/README.md` while computing each door's `called-by` count, so every
generation added one to every row: measured, two consecutive runs differed in **48 lines** (`2 → 3`, `3 → 4`). A
gate whose own input is its own output can never pass, and the house was one `YMIR_SKIP` away from ignoring it.

The fix is three lines: the scan now skips every index file by name (`README.md`, `CAPABILITIES.md`). Measured
after: **two consecutive runs differ by 0 lines**, `--check` reports *current (594 files)* on both indexes, and the
whole ward set passes locally with **0 FAIL**. That is Rule 34 applied to a generator: *it proves its output or it
refuses it* — and a generator that cannot reproduce itself must not be allowed to certify anything.
