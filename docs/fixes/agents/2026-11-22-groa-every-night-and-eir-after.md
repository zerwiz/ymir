# Gróa every night, and Eir after her, on every install

**Date:** 2026-11-22 · **Component:** agents (`bin/agents/groa-agent/`) · **Plan:** 350 part C

## What was wrong

Measured on 2026-11-22: `groa-agent.timer` fired every night on the three machines and failed on all of them.

- On this machine and on the heart, `groa-agent.service` ended `status=4/NOPERMISSION` at about 04:21. The
  exit code was Gróa's own verdict, *"NOT whole — owed: …"*: she updated, but Eir's surfaces were owed. systemd
  names code 4 NOPERMISSION, so the update looked like a permissions fault, and the unit was marked failed.
- The journal line `sudo: a password is required … COMMAND=/usr/bin/true` was the install's `sudo -n true`
  probe for the hound's step. It never prompted, but it read like a password prompt in an unattended run.
- Eir never ran after Gróa, so the surfaces she named as owed were never mended. On a second machine, the last
  run ended 124 (a timeout), and nothing named the stage that hung.

## What was built

- **Eir after Gróa, in the unit chain.** `seat.sh` writes `eir-night.service`. Gróa's unit starts it with
  `OnSuccess=` and `OnFailure=`, so the healer runs whatever the renewer said. Exit 4 is
  `SuccessExitStatus=` — "updated, surfaces owed" is the night Eir is for, not a failed night.
- **`eir-night.sh`** runs these stages, each bounded:
  1. It reads Gróa's last tick.
  2. `eir-doctor.sh check`.
  3. It mends only the surfaces whose risk is `safe`.
  4. It checks again.
  5. It renews the installed apps (`apps.sh update`). This stage is skipped while the desk is in a call or a
     smithy run is mid-phase.
  6. It hands the verdict to the arm holder with a Veil id, or through `rodd-arm.sh tell` where the Veil is not
     yet in the release.

  A stage that runs out of time is named (`HUNG: check (over 600s)`), and so is a Gróa that timed out. The
  verdict is kept in `state/renewal/last-night.json` and appended to `nights.jsonl`.
- **Never root.** Both units carry `YMIR_NO_SUDO=1`. The install's hound step then skips by name without
  probing `sudo`.
- **Every platform layer.** On systemd it writes user units. On macOS it writes one launch agent
  (`org.ymir.renewal`) that runs Gróa, then Eir. Without a user service manager, it says so and skips. The
  install and every update run `seat.sh` (Gróa re-seats herself after each update).
- **Eir's `renewal` surface** (`renewal-check.sh`, risk `safe`, its mend re-seats the pair). It is red when the
  pair is not seated, when the last night failed, or when no night has run for 36 hours.

## Proof

- `bash bin/agents/tests/test_renewal_night.sh` — 18 passed.
- `bash bin/agents/tests/test_eir_register.sh` — 19 passed. (`test_eir_true_mends.sh` has 16 passing and the
  same 2 failing on clean `main`: its hook pushes to a temporary remote.)
- On this machine, `systemctl --user start eir-night.service` finished in 4 min 18 s. The journal reads: *the
  night on nidavellir (e77a6bcf03b8): owed — Gróa rc 4; Eir mended: nothing; could not mend: armpin runtimepin
  seats; …; apps updated: odrerir sessrumnir smidja bilskirnir hvergelmir rodd*.
- The hand run of `groa-agent.service` showed one more thing. Gróa's update re-seats her units from the
  **pinned** release, so until a release carries this change, each nightly run puts back the old unit, with no
  chain. The chain holds from the first release that carries it.
