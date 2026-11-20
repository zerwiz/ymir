# Rödd raises headless, and the GPU card rides into the host

**Date:** 2026-11-10 · **Component:** voice · **Doors:** `apps/rodd/start.sh`, `bin/voice/voice-door.sh`

## What was wrong

Two edits were sitting **uncommitted in the main checkout** — on a branch 55 commits behind — so the work
existed on one machine and nowhere in the record:

- `apps/rodd/start.sh` gained `--headless`: raise the same pipeline (host · tunnel · toolbox · client) and
  run the terminal client instead of opening a window. `host_seat()` became `host_seats()`, because more than
  one seat can serve the host now.
- `bin/voice/voice-door.sh` did not pass `CUDA_VISIBLE_DEVICES` into the host unit at all, so a machine that
  pins the GPU by that variable silently ignored the pin and the voice host chose its own device.

A third-party consequence of the first: `--check` grew a `headless client` row, which is how the state is now
read without a window.

## What was forged

Both edits committed, with the registers regenerated (`bin/gates/inventory.sh`). The `--headless` road and the
`CUDA_VISIBLE_DEVICES` passthrough are the same code, unchanged: this commit moves stranded work into the
record rather than rewriting it.

## Verified

```
$ bash -n apps/rodd/start.sh              # syntax
$ bash apps/rodd/start.sh --check
host 8890 answers       down      # honest: nothing is raised on this seat right now
window running          5
headless client         1
```

## Notes

The registers (`bin/*/INDEX.md`) were regenerated, not hand-edited: `bin/gates/inventory.sh` is the only writer.

## CHANGE LOG

- **2026-11-10** — the stranded work moved into the record, unchanged.
