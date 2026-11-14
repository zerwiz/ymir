# The handoff door wrote a packet its own check refused

**Date:** 2026-11-14 · **Component:** forge (`bin/forge/handoff-packet.py`, `bin/gates/tests/test_handoff_packet.sh`) · **Plan:** 275 (found while delivering `bridge-and-rail`)

## What was wrong

`handoff-packet.py write --base origin/main` resolved the ref to a sha to derive the diff, then wrote **the ref it was
given** into the packet's `base` row. `handoff-packet.py check` needs a full sha there — it re-derives the diff and
compares it with the packet's `changed[]` — so the door refused the packet the same door had just written:

```
handoff-packet: REFUSED — packet bridge-and-rail cannot be trusted
  "base","no full sha: 'origin/main' — the diff cannot be verified"
```

A smith following the documented road (`--base REF`) hit this every time. The existing test never saw it because every
case passed a sha.

## The fix

The resolved sha is what goes into the packet; `--base REF` is still accepted at write and resolved once. The reason is
written beside the line in the door, so the next hand knows why the ref must not be stored.

## Verified

`bin/gates/tests/test_handoff_packet.sh` gains two assertions: a packet written with `--base work` (a ref) records a
full sha, and that packet then passes `check` — the door's own packet passes the door's own check. The suite is 19
passed / 0 failed. Wired into `bin/gates/ci-verify.sh` as `handoff-packet`, because a test that runs nowhere is a
silent absence (it existed and ran nowhere until now).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #757
