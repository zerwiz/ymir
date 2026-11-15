# A lone `-e` is not a full extension set — the seat that would not start

**Date:** 2026-11-13 · **Component:** extensions · **Doors:** `bin/seat/pi-door.sh`, `bin/seat/valknut-load.sh` · **Plan:** 283

## What was wrong

The desk showed the operator's own words on the glass: **"Couldn't start Brokk"**, then forty-four lines of

```
Error: Failed to load extension "~/ymir-runtime/.pi/extensions/constellation/index.ts":
Tool "constellation_list" conflicts with ~/ymir/.pi/extensions/constellation/index.ts
…
Hint: Start without extensions using "pi -ne".
```

Two trees, byte-identical, loaded at once: the pin's (named in `~/.pi/agent/settings.json`) and the
checkout's (auto-discovered from `<cwd>/.pi/extensions`). pi de-duplicates on the resolved path alone, so
every tool registered twice and pi exited before a seat existed. RULES/13: two load paths seats nobody.

The house already had the cure — the one-home door at `~/.pi/agent/bin/pi` — and the app already spawned
it. Measured in the app's own log (`state/sessrumnir.log`), the argv was:

```
/home/heimdall/.pi/agent/bin/pi --mode rpc --provider … --model … --continue \
  -e /home/heimdall/ymir/apps/sessrumnir/resources/pi-desktop-permissions.ts
```

The door's rule was *"the caller already names its extensions (`-ne` / `-e`) → pass through, untouched."*
A lone `-e` adds one extension; it does **not** turn discovery off. So a door built to prevent exactly
this collision read the caller's `-e` as ownership and passed the collision straight through.

## What was forged

- **Only `-ne`/`--no-extensions` means "the caller owns the set".** A lone `-e` now still gets the
  one-home decision, and the door adds its own pins on top of the caller's extension: `-ne -e <home> -e
  <caller>`. Its header states the measured case so the next reader does not re-derive it.
- **The gate can fail.** `bin/seat/valknut-load.sh --check` grew four lines: the door is seated; the `pi`
  first on PATH *is* the door (not a shim in front of it); the door's verdict in this tree is one home;
  and a load actually happens here — `pi --list-models` in this tree must print **zero** `conflicts with`
  lines. The fifth line repeats that with the app's own argument shape (a lone `-e`).
- **Proved able to fail, then made to pass.** With the previous door restored:
  `a seat that adds its own -e still loads once  FAIL (44 conflicts)`, exit 1. With the fix: `PASS (0
  conflicts)`. Shadowing the door with a bare npm `pi` on PATH: `pi first on PATH is the door  FAIL —
  /tmp/shadow-pi/pi shadows it`.

## What the seat does now

Same spawn, same argv, from the running app (`piDesktop.pi.getStatus()`):

```
{"status":"running","pid":1606364,"error":null,"engine":"pi"}
```

That is the proof the fault is gone: the app starts a seat, and the seat sits.

## Why this is the same fault as the hearth

Plan 283's first finding was one capability with three implementations; this is one capability with two
load paths. Both are *the same thing counted twice*, and both were invisible to a gate that listed
cleanly — `valknut-load --check` passed all evening while the seat could not start.

## Files

- `bin/seat/pi-door.sh` (the rule, and the header that records why)
- `bin/seat/valknut-load.sh` (`--check`: the door, the PATH, the verdict, the load, the app's shape)
- `bin/desktop/sessrumnir-launch.sh` (exports the seat's PATH with the door first, because the Electron
  main process can arrive with no PATH at all — measured: an 10,874-byte environment of NUL bytes)
- `apps/sessrumnir/src/main/pi-binary-resolution.ts` (the door is asked for by name, before npm's global
  prefix or a PATH search; a new `house-door` source so Diagnostics says the truth)
- `apps/sessrumnir/src/shared/ipc-contracts.ts`, `src/renderer/src/components/diagnostics-panel.tsx`,
  `resources/locales/en/translation.json` (the label for that source)
- `apps/sessrumnir/bin/sessrumnir.js` (`--remote-allow-origins=*` with the DevTools port: without it every
  scripted client's websocket is refused and the door answers `/json` and nothing else)

## CHANGE LOG

- **2026-11-13** — written with the fix; the conflicting argv and the 44 lines are from the app's log.
