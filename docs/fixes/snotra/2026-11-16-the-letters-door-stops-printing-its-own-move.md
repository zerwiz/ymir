# Fix — the letters door stops printing its own move

**What was wrong.** Every letter sent through `mail-send.sh` printed this, beside a send that had worked perfectly:

> `snotra: bin/time/snotra/ has MOVED to systems/snotra/ — call systems/snotra/services/approve/snotra-approve.sh (plan 129)`

The door called the **retired shim** at `bin/time/snotra/snotra-approve.sh`, which execs the real door in
`systems/snotra/services/approve/` and says so — correctly, because it exists for callers nobody has repointed. The
letters door *was* that caller, so it was the one printing the move it had already been told about.

**Why it matters more than a noisy line.** A warning that appears on every successful send stops being read, and then the
one time it says something real nobody sees it. The Allfather read it as a fault in the send — which, from the outside,
is exactly what it looked like.

**What was done.** One line: the approval door is now addressed at its real path. The shim stays where it is for any hand
that has not been repointed yet — that is what a retired shim is for — and the test path beside it was left alone, because
`test_outbound_gate.py` has **not** moved and repointing a path that is already correct is how a fix becomes a new fault.

**Proof.** A dry run of the door through the same path that used to print the line:

```
$ bash systems/snotra/services/letters/mail-send.sh draft --dry-run …
eml	/tmp/tmp.XXXX.eml        ← no MOVED line
```

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #804
