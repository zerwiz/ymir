# The button is the door — the mic's one hand, wired

**Date:** 2026-10-31 · **Component:** snotra · **Status:** wired, awaiting a press

## The law, in his words

> "we have a button in Hlidskjalf that should activate the mic. thats the main way to the mic."

So the microphone is not authorised by a command line; it is authorised by a **person pressing a
button**. The gate added this evening — the script refuses unless `SNOTRA_LOCAL_ROOM=1` — is now
satisfied by that button and by nothing else in ordinary use.

## What changed

| file | change |
|---|---|
| `apps/hlidskjalf/server/index.ts` | `POST /api/snotra/live/start` spawns `snotra-live.sh` with `SNOTRA_LOCAL_ROOM: '1'`; the reason sits at the call site, next to the env |
| `apps/hlidskjalf/src/components/SnotraLive.tsx` | the modal is titled "Start listening in this room"; both the modal body and the idle note say the ear hears THIS ROOM's microphone only, and that an online meeting is joined by Snotra's bot, never by the mic |

## Verified / owed

`bash -n` is not the test for TS; the gate was rebuilt separately. **Owed:** one real press with the
gate rebuilt — the document grows, the stop closes the book — and a note on whether the refused path
still prints the right sentence when the script is missing.

**The shape of the law, once:** the button is the only hand on the microphone; the bot is the only
ear on an online meeting. The CLI markers remain as the fallback for a seat with no Hlidskjalf.
