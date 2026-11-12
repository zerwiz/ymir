# The night's twelve errands gathered into one push

**Component:** gates · **Date:** 2026-11-12

## What happened

Twelve finished branches were gathered by `bin/forge/gather.sh` into one integration branch, gated once and
offered as one pull request.

Six merges conflicted. Each was resolved in the integration worktree, keeping both sides' intent:

| Branch | Files | How it was resolved |
|---|---|---|
| `bilskirnir-desk` | `computer.ts`, `setup.sh` | the desk's `machineId()` road, worded for agents rather than bots; both env notes kept |
| `no-blue-no-purple` | four Bilskirnir colour files | the tree's existing house hues, which already match `web/src/lib/colors.ts`; the house-colour ward passes |
| `flash-only` | `eir-doctor.sh` | the surface list is the union (`bilskirnir` and `models`) |
| `no-helm-no-errand` | runtime doc, Eir, Rödd's helm and test, `seat.py` | union: the model allow-list and the helm gate both stand |
| `helm-knows-itself` | runtime doc, Rödd, Eir, `desktop-place.sh`, `watch.py` | see below |
| `hall-voice` | Bilskirnir `ARCHITECTURE.md`, `setup.sh` | both: the launcher entry stays step 7, the voice report becomes step 8 |

## Two roads to plan 257's pin

`no-helm-no-errand` and `helm-knows-itself` each built plan 257 H6–H8 separately. Where they collide, the
gathered tree takes the `helm-knows-itself` road:

- Rödd resolves her pin through `apps/rodd/src/pin.js`.
- Eir's `armpin` surface asks `bin/seat/armpin.sh`.
- A refusal goes through the notify door with `--key`, and a test hands the door a silent stand-in, so no test
  reaches the operator's desktop.

`bin/pi/arm-pin.sh` and its library stay, because the arm client and Gróa use them.

`watch.write_lease` writes the helm's identity tokens. It writes `pin=` and `pin_behind=` alone only when no helm
is resolved, so the lease never carries them twice.

## Three wards mended on the gathered head

- `public-data-guard`: a test used a tailnet-shaped hostname; it is now `newbox.example.net`.
- `rules-compliance-guard`: `bin/records/tests/test_comms.py` is now executable.
- `pkill-guard`: the desk's screen stop now kills the pid in the X server's lock file, never a pattern.

> [!IMPORTANT]
> `desktop-main-guard` judges this machine's installed launchers, not the tree. The seated Bilskirnir launcher
> points into an errand worktree. Only `bin/host/omarchy-install.sh` from main can mend it, after this lands.
