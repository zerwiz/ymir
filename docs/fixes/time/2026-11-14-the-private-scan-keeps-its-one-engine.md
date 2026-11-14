## time · 2026-11-14 — the private scan keeps its one engine after merging main

### Why

PR #750 (a gather batch) was **CONFLICTING**: `bin/time/nornir-job-private-scan.sh` had evolved on both sides.

### What the two sides were

- **the branch** (this batch) carries the newer design: the names of people, clients and companies are judged by ONE
  engine, `bin/gates/agnostic-audit.sh`, which the branch also ships; the allow list lives in `config/` so the reason
  for every accepted finding travels with the clone rather than dying in the gitignored `state/`.
- **main** still carries the older shape: `hodd/identity/nda-names.txt` as a second list beside the engine's
  `hodd/identity/public-deny.txt`.

### The resolution

The branch's side, whole. It is a **superset**: it keeps main's `hodd/identity/machine-homes.txt` rule (the machine's
own `/home/<user>/` is an address, and baking one into a public script breaks the rule the script enforces), and it
replaces the second names list with the one engine — which the branch ships as `bin/gates/agnostic-audit.sh`. Taking
main's side would have kept two lists and lost the engine.

This is the one shape the interim rule does not cover: main's copy was the *older* evolution of the file, not a newer
list to preserve. `bash -n` is clean and no conflict marker survives.
