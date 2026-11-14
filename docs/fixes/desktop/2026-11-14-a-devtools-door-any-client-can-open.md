# desktop · 2026-11-14 · A DevTools door any client can open, and a profile a second instance can own

## What

`scripts/electron.sh` — the launcher behind Hlidskjalf, Smíðja and Óðrerir — now does two things it did not:

1. When `YMIR_DEVTOOLS_PORT` is set it passes `--remote-allow-origins=*` beside `--remote-debugging-port`.
2. The profile a window writes into comes from `YMIR_APP_USER_DATA_DIR` when set, else the operator's own
   `~/.config/<app>` as before.

## Why

Chromium refuses a DevTools websocket that carries an `Origin` header unless the origins are named. Sessrúmnir's
launcher learned this on 2026-11-13 and carries the flag; the other three apps' launcher did not, so their door
answered `/json/version` and then failed the handshake — a door that exists and cannot be opened, which is the
false green this house keeps paying for. (The soak's own client sends no `Origin` at all, so the harness works
either way; the flag is for every other scripted client.)

A soak needs the same app twice — once as it was, once as it is — and Electron's single-instance lock is per
profile. Without an override, a second instance merely focuses the running window and quits: measured on this
machine at 12:37, a soak's raise of Hlidskjalf raised the operator's window and opened no door. With the
override the soak raises its own instance in a throwaway profile and never touches the open one.

## Proof

- Sessrúmnir, whose launcher already had both, is soaked end to end (report: `state/eindri-reports/leak-soak.md`).
- Hlidskjalf is a **named skip** in this release: the pin predates this change, and the soak refuses to restart a
  window the Allfather has open. After the next release flip, `bin/gates/soak.sh hlidskjalf` raises its own
  instance and closes it.

## Not changed

The operator's default profile path, the GPU/ozone policy, the single-instance lock and the window class are all
untouched. A launcher that sets nothing behaves exactly as before.
