# Two mends stop undoing each other, and Gróa can end whole

**Component:** seat (plan 369, item 6) · also `config/units.yaml`

## What was wrong

Gróa's nightly update ended with `groa-update.sh exited 4` (`7af321c99 → e5ebd388c`). Exit 4 means
"not whole": surfaces Eir calls `safe` were still broken after Eir's safe mend. Two of them could never
be mended:

- **`claudehooks`.** `bin/seat/harness-extensions-install.sh` seats one digest hook,
  `bash "$HOME/.claude/hooks/saga-session.sh"`, and prunes a hardcoded
  `<root>/bin/time/saga-session-start.sh` SessionStart hook as a second digest. `bin/seat/seat-reap.sh`
  seated exactly that hardcoded hook. Eir's mend ran both (`claudehooks`, then `seats`), so each undid
  the other. The night's log shows `eir: mended claudehooks` and `eir: mended seats`, and then
  `claudehooks` owed again. Every Claude session also printed the Sága digest twice.
- **`runtimepin`.** `eir-night.service`, written by `bin/agents/groa-agent/seat.sh` and fired by Gróa's
  own unit, names a Ymir tree but was not in `config/units.yaml`, so it read `UNREGISTERED`.

## What changed

- `seat-reap.sh` counts the house hook (`…/.claude/hooks/saga-session.sh`) as seated. When the house
  hook script is on disk, the house hook is the one it seats. Without the script, it still seats its
  own door, so a bare seat keeps a digest.
- `config/units.yaml` registers `eir-night` as an adopted unit.

## Proof

- `bin/seat/tests/test_seat_reap_one_digest_hook.sh`: 6 passed, 0 failed. Against main's
  `seat-reap.sh` it prints 2 passed, 4 failed.
- `bin/engine/units.sh check` prints `"eir-night","unit","ok","on the pin, in the register"`.
- `bin/agents/tests/test_eir_mends.sh`: 5 passed. `test_seat_reap.sh` has 2 failures (grace seat), and
  the pin shows the same 2.

## What the machine still needs (not code)

- After this lands and the pin moves: `bin/agents/eir-doctor.sh fix claudehooks`. It seats
  `errand-stop.sh` (new in #924, added after the night's run) and prunes the duplicate digest hook.
- The other owed rows are `ask` or `never`, so they are the operator's: `hoard` (a `.sync.lock` inside
  `hodd/saves`), `seatreap`, `autoboot` and `vaultkeys`. They are named in the night's fault report, and
  `config/owed-accepted.txt` is where he may accept one.
- The pin was not flipped.
