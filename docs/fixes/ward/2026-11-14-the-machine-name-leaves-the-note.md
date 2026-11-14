# The shipped note names no machine, only "this machine"

**Date:** 2026-11-14 · **Component:** ward · **Doors:** `docs/fixes/ward/2026-11-14-the-leak-ledger-and-the-restart-storm-ward.md` · **Plan:** 286 (P0, P4)

## What was wrong

The fix note that ships with the leak ledger said where its proof ran: two added lines named the box the
proof stood on, in the first line of each of the note's two measurement sections. A document in the public
tree that names one machine is not agnostic — the same note is read on a hand, a server or another
operator's computer, and the name would be one that is not theirs (RULES/25).

## What was forged

The two lines now say **this machine**. Every number they carry is unchanged — 39 targets a pass, about two
seconds, the deliberately looping unit and its restarts. The name left; the measurement stayed.

The correction is recorded this way and not by rewriting the note's history: the note is append-only
(RULES/06), so its own CHANGE LOG gains a dated line saying what was corrected and why, and this note is the
new file that names the fix.

## What was not done

- No code changed: the doors, the timer, the tests and the configuration are as the accepted branch had
  them; this is a correction to a shipped document only.
- The recipe in the note still names `bin/ward/restart-storm.sh` and `bin/ward/soak-sampler.sh` — repo
  paths, not a machine's, so they stay.

## CHANGE LOG

- **2026-11-14** — written at the helm's correction, under the agnostic law (RULES/25).
