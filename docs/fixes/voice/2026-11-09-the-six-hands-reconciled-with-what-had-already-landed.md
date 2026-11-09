# The six hands reconciled with what had already landed

**Date:** 2026-11-09 · **Component:** voice · **Door:** PR #610 (`eindri/context-left`) · branches merged onto `main`

## What was wrong

PR #610 was opened 04:47 and main moved 32 commits underneath it before anyone merged it. By the
time it was rebased, **half of it was already on main in a newer form**, and the collision was not
cosmetic — Git refused sixteen files:

- *every message opens* (plan 230) had landed on main as a refined version of the same work. Main's
  own header says of the branch's inline fix: *"that fix is SUBSUMED, not lost"*. The branch's
  draft of it was still in this PR.
- **four of Rödd's hands** (`arm_who`, `eindri_list`, `eindri_send`, `calendar_write`) had landed on
  main, including a working calendar door — so the branch's second implementation of the same door
  and the same tool collided head-on.
- `voice_tools.py` arrived with **two `calendar_write` tools and two `arm_who` tools**, two TOOLS
  declarations, and the branch's `arm_tell`/`seat_wire` left unwired once the duplicate block was
  dropped (their registrations travelled with the duplicate).

## What was forged

**Main's newer work wins where it already landed; the branch keeps what is genuinely new.**

| kept from the branch | dropped as superseded |
|---|---|
| `.pi/extensions/context-left/` and `bin/seat/context.sh` — the context budget | `bin/notify/desktop.sh` (main folded it into `open-target.sh`) |
| `arm_tell` | the branch's draft of `every-message-opens.md` |
| `bin/seat/sessrumnir-wire.sh` + the three channels in `apps/sessrumnir/src/web-server.ts` | the branch's calendar door (main's is live and proven) |
| `.agents/tests/context-left.test.sh`, `.agents/tests/rodd-hands.test.sh` | `.agents/tests/open-target.test.sh` (main ships `bin/notify/tests/test_open_target.sh`) |

Two real defects were mended on the way, both in main's code, both found by the branch's tests:

1. **`calendar-grant.sh` died instead of explaining itself.** `CAL_TOKEN_WHY="$CAL_VAULT_WHY"` under
   `set -u`, at the exact moment the door needed to say why it could not read the grant — because a
   failure inside a command substitution sets its reason in a subshell the parent cannot see. The
   vault is now asked in the *parent* shell first, and every reason carries a default.
2. **`arm_who` and `arm_tell` spoke two different words** for the same silence ("Nobody is holding
   the arm" vs "Nobody is armed"). One sentence now, the one the test asserts.

The `rodd-hands` fixture also had to learn main's door: it hands a grant through
`CALENDAR_SECRETS_FILE` by **key**, never as env values.

## Verified

```
$ bash .agents/tests/rodd-hands.test.sh        # 7 of 7 — all claims proved
$ bash .agents/tests/context-left.test.sh      # 12 of 13
$ python3 -c "import ast; ast.parse(open('bin/voice/voice_tools.py').read())"
$ bash -n systems/snotra/services/calendar/calendar-grant.sh
```

**One assertion is still red, and it is not this merge's:** *"the voice repeats the extension's
reading"*. It fails identically on a pristine checkout of `origin/eindri/context-left`
(`/tmp/pristine-610`), so it is the PR's own defect — the published reading the voice reads is the
`tokens: null` one rather than the final good one. Recorded here rather than hidden; the next hand
on this door owns it.

## CHANGE LOG

- **2026-11-09** — the reconciliation, written the hour it was done.
