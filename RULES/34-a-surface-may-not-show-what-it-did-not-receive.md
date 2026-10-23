# Rule 34 — a surface may not show what it did not receive

**A panel, a letter, a report or a file that Smíðja or Snotra puts in front of a person may not present a value it
did not actually receive.** A refused read is not zero. A failed probe is not "down". An unknown attribution is not
a name. An empty file is not a transcript. If the thing cannot be known, the surface says **that**, in words, and
shows no figure.

## Why this rule exists

Measured on 2026-10-23, in one evening, six times:

| the surface | what it showed | what was true |
|---|---|---|
| Hlidskjalf · Snotra panel | **0 meetings · 0 decisions · 0 actions** | 2 meetings and 24 decisions on the shelves — the API had answered **401** |
| Hlidskjalf · Well tile | **"bridge down"** | `GET :4602/health` → **200**, 167 episodes |
| Hlidskjalf · Nornir tile | **"STOPPED · 0/0 jobs"** | the runner was alive: `cron: running pid=… jobs=29` |
| Hlidskjalf · Mánagandr | *"The cache is fresh and the window is empty — no events booked."* | the read had failed; the calendar held events |
| `snotra-harvest.sh speakers` | **three WAV "tracks"**, exit 0 | the capture log's `pcm` is **not PCM**: full-scale noise (mean magnitude 16 354; speech is 500–4 000) |
| a Snotra letter | *"Silence is recorded as provisional acceptance"* and a date **2026-10-26** | the record carries no such policy, and its own action is due **2026-10-24** |

And the original of the family, from the same day: **8 191 transcription calls returned `ok: true` with no words**,
and the meeting folder was reported "transcribed".

Every one of them is the same defect wearing different clothes: **a fallback that reports success.** The house has
already legislated the *door* half of this (a door fails loudly; a clean skip is printed — Rule 25); this rule is the
*surface* half.

## The law

1. **No figure without a receipt.** A number on a surface must come from a response that was actually received. On a
   refused, failed or absent read, render `—` (or nothing) and a sentence naming the refusal — never `0`.
2. **No diagnosis from an absence.** "Down", "stopped", "empty", "none" are *conclusions*; a surface may conclude
   only from a successful read. A failed probe says *"could not read"* and names the probe.
3. **No inferring identity, state or policy.** An unattributed quote stays `decided_by: null`; a rule the record
   does not carry is not printed; a file whose content cannot be verified is not named after what it was meant to be.
4. **A fallback carries its own warning, on the same line as the value.** If a surface falls back to a cache, a
   summary or a stale copy, the value is marked `cached`, `stale` or `unverified` where it is shown — not in a
   footnote a reader can miss.
5. **A generator proves its output or refuses it.** Anything Smíðja or Snotra emits (a card, a letter, an audio
   file, a panel state) is checked against what it claims before it is written: the letter cites record ids; the
   audio decodes to speech; the card is read back from the board; the panel's figure matches the response.
6. **This rule binds every surface, including the ones built by an agent in a sandbox.** A prototype that lies is
   not a prototype; it is a rumour with a build step.

## What it obliges, concretely

- an API client in a UI throws on a non-2xx and the component renders an *auth/refused* state, not empty state;
- a metric tile takes `value: number | null` and renders `—` for null, with a `delta` that says why;
- a door that produces a file verifies the file (decode it, read it back, hash it) before printing `ok`;
- a renderer of prose may only emit: the record's own words, its ids, or a label — never a sentence the source
  cannot cite (the letter law of the same day, now general).

## What it does not forbid

- **A clean skip is still a pass** (Rule 25) — saying "not tested, because X" is exactly what this rule wants;
- **estimate and inference are allowed when labelled as such** (`candidate`, `inferred`, `unconfirmed`), because an
  honest label is not a lie;
- **caching is allowed**, provided the surface shows that it is a cache and when it was filled.

## Related

Rule 06 (append-only), Rule 11 (never delete), Rule 25 (a clean skip is a pass), Rule 26 (the well appends),
Rule 30 (audio is ephemeral — and is never called a transcript), Rule 33 (the ear hears the meeting, not the room),
Rule 32 (*the send is the operator's*), whose incident is the letter half of this rule.
