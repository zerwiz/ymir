# A hold declares the caller's own role

**Date:** 2026-11-19 · **Component:** voice · **Door:** `bin/voice/rodd-arm.sh hold` · **Test:**
`bin/voice/tests/test_rodd_arm.sh`

## What was wrong

`bin/voice/rodd-arm.sh hold` always wrote `role=rodd` into the arm's role sidecar. Measured on 2026-11-19: a pi seat
took the helm with `hold`, and the sidecar said Rödd held it. The role had to be corrected by hand to the caller's own
role. The room line said "Rödd takes the helm" for a hold that was not hers.

## What was forged

- `hold` resolves the role from the session's own harness, the same way the arm client does: `pi` leases
  `counsellor`; `claude`, `opencode`, `codex` and the other harnesses keep their own name; an unknown harness is the
  counsellor.
- `hold --role <role>` (or `BROKK_ARM_ROLE`) names it explicitly. Rödd's own hold is `hold --role rodd`. An unknown
  role is refused.
- The hold row now carries a `role` column, and the room line names the real holder. `release` names the role that
  is giving the helm back.
- A hold still never steals: the live-holder refusal and the speech gate are unchanged.

## Proof (measured)

`bash bin/voice/tests/test_rodd_arm.sh`, with a new section 10 that holds from a process whose name is `pi`:

```
  ok   a hold from a pi seat exits 0
  ok   a pi seat's hold leases the counsellor role
  ok   the hold row names the role
  ok   the room names the counsellor, not Rödd
  ok   the counsellor releases the helm
  ok   the release names the counsellor
  ok   an unknown --role is refused
  ok   hold on a live holder refuses with the holder named
test_rodd_arm: 68 passed, 0 failed
```

`bash bin/seat/tests/test_desk_failsafes.sh` → `test_desk_failsafes: 44 passed, 0 failed`.

## CHANGE LOG

- **2026-11-19** — written with the change it describes.
