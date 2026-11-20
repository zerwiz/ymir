# Two false alarms, both the same fault: a door judged by something it never claimed

**Date:** 2026-11-20 · **Component:** ward (`bin/ward/garmr/rules.py`) and records
(`bin/records/gimle-tunnels-check.sh`) · **Errand:** `ward-honest`

## What was wrong

The operator's phone carried one alarm every quarter hour and another every half:

```
[garmr/CRITICAL] CRITICAL: chmod (pid 2818118, uid 1000) changed  at 2026-11-19T18:08:54+0100 — passwd, shadow, sudoers or an authorised key
[cron/HIGH] job failed (rc=1): bin/records/gimle-tunnels-check.sh --quiet — no output
```

Both were lying, in the same way: each asserted something its own evidence did not support.

**The identity alarm named nothing.** Read the line — `changed  at`, with two spaces where a file should
be. The finding carried `class: identity` and an **empty target**: the record matched the audit KEY, not a
path. The rule then printed a fixed sentence about `passwd, shadow, sudoers or an authorised key`, so a
record that could not say what changed was announced as the most serious thing in the house, twelve times a
night.

**The tunnel round called three open doors broken.** `board`, `whiteboard` and `documents` answered `401` —
they were up and asking for a credential, which is exactly what RULES/24 asks of a public surface. The check
counted only `200`/`3xx`/`404` as healthy, so a guarded surface was a failure, and the cron exited 1 every
quarter hour on a machine where nothing was wrong.

## What was built

| file | change |
|---|---|
| `bin/ward/garmr/rules.py` | an identity record with **no path** is now `HIGH` and says so — *"matched the identity watch with no path in the record — no file is named, so read this as a watch to check, not as a change to passwd, shadow, sudoers or a key"*; a named path is still `CRITICAL` |
| `bin/records/gimle-tunnels-check.sh` | `401`/`403` is `ok` with the note `guarded (auth required)`, because a surface that asks for a credential is the ward working |
| `bin/ward/tests/test_garmr_identity_named.sh` | the proof, three assertions |
| `bin/gates/checks.d/0507-garmr-identity.sh` | the gate that holds it |

## The proof

```
$ bash bin/ward/tests/test_garmr_identity_named.sh
  ok   an identity record with no path is HIGH and claims no file
  ok   a named path is still CRITICAL and names the class of file
  ok   another identity file is judged the same way
garmr-identity: 3 passed, 0 failed

$ bash bin/records/gimle-tunnels-check.sh | tail -1
8 up · 0 failing          # was "5 up · 3 failing"
```

## What this does not decide — and the finding under both

**Garmr is not watching on this machine, and says it is.** Measured while these lines were being fixed:

```
mode                    ON — watching
hound (system)          inactive
audit rules armed       0
heartbeat               never
```

and `bin/ward/garmr.sh verify` printed *"garmr: surfaces whole"*. A guardian whose mode says ON while no
audit rule is armed and no hound runs is the false green this house has paid for twice; `verify` should
refuse that sentence, and it does not. That is a separate change with its own proof, recorded here so it is
not lost: the alarms above could not have come from this seat's instance in its present state.

## CHANGE LOG

- 2026-11-20 — written while the two alarms were ringing.
