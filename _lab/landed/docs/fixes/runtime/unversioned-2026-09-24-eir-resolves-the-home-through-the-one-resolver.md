## runtime · unversioned · 2026-09-24 — Eir resolves the home through the one resolver

### Why
`bin/agents/eir-doctor.sh` carried its own home default:

```bash
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
```

This is the same fault the hardcoded hunt fixed everywhere else, and Eir was missed.
On a machine whose home is named differently the doctor therefore inspected
`$HOME/Documents/ymirhome`, which does not exist, found no hoard there, and reported
**`hoard` broken** on a home that was in good order. A diagnostic that reads the wrong
home cannot be trusted about any home.

### What
The home now comes from `ymir_home_root` (env → the recorded choice → the one default
in `bin/vault/hoard-lib.sh`), sourced from `bin/vault/hoard-lib.sh` beside the script, with the old
literal kept only as a last-resort fallback when the resolver is absent.

**What it revealed once fixed:** with the right home, the hoard surface fails on its
third condition, a session-lock pointer naming `$HOME_SEAT/.local/state/ymir/brokk.lock`.
That path is not drift and not the doctor's to mend: it is written by the **substrate
container**, whose `$HOME` is `$HOME_SEAT`, into the state directory the host and the
container share. The pointer is machine-local by design and the home is synced, so a
container and its host cannot agree on it. Reported here rather than papered over; it
wants a decision (a machine-local pointer path, or accepting the conflict).

### Files
- `bin/agents/eir-doctor.sh`
