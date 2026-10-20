# Meeting sign-off

**What it is.** A record becomes official when the people in the meeting confirm it and
the Chair signs. Signing means the record is accurate, not that you agree with the
decision.

## Commands

```sh
OUT="$YMIR_HOME/svartalfaheim/synteon/meetings/2026-10-20-roadmap"

bin/time/snotra/snotra-signoff.sh init   "$OUT"   # one entry per participant
bin/time/snotra/snotra-signoff.sh ask    "$OUT"   # one Gmail draft per pending person
bin/time/snotra/snotra-signoff.sh sync   "$OUT"   # read confirm / objection: replies
bin/time/snotra/snotra-signoff.sh record "$OUT" "A Participant" confirmed --note "checked the patent wording"
bin/time/snotra/snotra-signoff.sh render "$OUT"   # signoff.md
bin/time/snotra/snotra-signoff.sh status "$OUT"
```

State lives in `signoffs.json`; the human sheet is `signoff.md`.

## The reply parser

`sync` searches Gmail for the sign-off thread, matches the sender to a participant, and
reads a line that is exactly `confirm` or starts with `objection:`. It ignores quoted
history. A dry run is `sync "$OUT" --dry-run`.

## Limits

- Grade A should require every participant; the tool currently approves when every entry
  is confirmed or abstained, so the Chair must check an A record before signing.
- A live reply has not yet been exercised in production; the parser returns
  `no replies found` on a clean inbox.
