# A borrowed release carries the workspace's own modules

**Component:** engine (`bin/engine/release.sh build`)

## What broke

`release.sh build` stopped at step 15, the Hliðskjálf build. The log ended with
`TS2307: Cannot find module '@xterm/xterm'` and a run of `TS7006` implicit-any errors in
`apps/hlidskjalf/src/components/Terminal.tsx`. The pin could not move, so nothing merged since
the last flip ran on the machine.

## Why

The dependency was declared. `apps/hlidskjalf/package.json` names `@xterm/xterm ^6.0.0`, and the
root lock places it at `apps/hlidskjalf/node_modules/@xterm/xterm`. It is nested in the workspace,
not hoisted to the root.

When the lock matches the running release, the build skips `npm ci` and hard-links the running
release's root `node_modules`. It did not copy the workspace's own `node_modules`. The release that
was running had been built without that folder, so the new release had no `@xterm/xterm` at all.
The `TS7006` errors came from the same cause: with the module missing, its callback types became `any`.

## The fix

Before it borrows, the build reads the lock for every workspace folder that has nested packages,
such as `apps/hlidskjalf`.

- If the running release has each of those folders, the build hard-links them too, next to the root one.
- If any of them is missing, the build does not borrow and runs `npm ci` instead.

`Terminal.tsx` and `package.json` did not need to change.

## How it was checked

`bin/engine/release.sh build --ref origin/main --from ~/ymir` ran to the end and proved the release.
The release sha is in the errand report.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
