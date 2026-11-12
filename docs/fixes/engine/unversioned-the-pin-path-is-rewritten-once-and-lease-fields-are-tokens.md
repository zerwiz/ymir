## engine · unversioned · 2026-11-12 — the pin rewrite matches whole path components, and lease readers take one token

### Why

Two faults came out of the same runtime move on 2026-11-12.

1. `units.py` `retarget()` replaced the working-tree root with a plain string replace. A tree at
   `~/ymir` matched inside the pin `~/ymir-runtime`, so `skirnir-telegram.service` became
   `WorkingDirectory=~/ymir-runtime-runtime/systems/skirnir` and failed at CHDIR (status 200).
2. `lease_alive()` in `bin/pi/syn-watch-arm.sh` and the reader in `bin/seat/seat-wire.sh` read the
   lease's `state=` with `sed 's/.* state=//p'`, which keeps the rest of the line. Since PR #692 the
   lease carries identity fields after `state=`, so the state never matched and the Stop hook printed
   "stale: arm service is down - no live lease" while the lease was alive.

### What changed

- `retarget()` now matches a root only as a whole path component (not preceded by a path character,
  not followed by a name character) and skips a match where the pin already stands. A unit already on
  the pin is untouched, and a second `write` changes nothing. Drop-ins (`*.service.d/*.conf`) go
  through the same function.
- Both lease readers take `state=` as one space-delimited token, as `lease_part()` does.
  Other lease readers already used `[^ ]*`.

### Proof

- `bin/engine/tests/test_units.sh` section 4b: a tree whose name prefixes the pin moves once, never
  doubles, a unit on the pin is byte-identical, a drop-in moves once, a second write is a no-op.
- `bin/pi/tests/test_lease_fields.sh`: a lease with the new identity fields is alive; another state is
  refused; no greedy `state=` reader remains in `bin/` or `src/`.
