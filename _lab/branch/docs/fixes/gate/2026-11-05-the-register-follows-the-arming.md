# The register follows the arming

**Date:** 2026-11-05 · **Component:** gate · **Door:** `bin/README.md`

`bin/ward/garmr.sh` grew again — the `-D` line and the `SUDO_USER` resolution — so `bin/README.md`,
which records every door's line count, went stale and `inventory-guard` refused the push that carried
the arming fixes. Regenerated with `bin/gates/inventory.sh`; the generator is reproducible, so the
diff is one number and it can be checked rather than trusted.

The lesson the ward keeps teaching this seat: a register is a measurement of the tree, and a change
that moves the tree moves the measurement in the same commit or the gate is right to stop it.
