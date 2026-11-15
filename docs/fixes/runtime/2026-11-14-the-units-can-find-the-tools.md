# The house's units can find the house's tools

**Date:** 2026-11-14 · **Component:** runtime (`tools/web/systemd/*.service`, `tools/mill/systemd/*.service`) · **Plan:** 275 item 26

## What was wrong

The Sága digest drawn inside `hlidskjalf-gate.service` printed
`error: gh is not installed — the PR list cannot be read`, while `gh --version` answered in every shell. `gh` is
installed under mise (`~/.local/share/mise/shims/gh`), and the unit carried
`Environment=PATH=%h/.bun/bin:/usr/bin:/bin` — a PATH that stops short of the shims. The same shape was in every
house unit, so any tool a service shells out to could be "not installed" inside a unit and present at a prompt.

## The fix

Fifteen unit templates — six under `tools/web/systemd/` and nine under `tools/mill/systemd/` — now end their PATH with

```
%h/.local/share/mise/shims:%h/.mise/shims
```

The shims are **last**, after `/usr/bin:/bin`, on purpose: a system binary always wins, and only a tool that is
otherwise missing is resolved through mise. Putting a shim directory first would silently shadow `python3`, `git` or
`node` with a second interpreter chosen by a config file — a worse fault than the one being fixed.

The gate and the bridge carry the reason in a comment, because they are where it was measured.

## Verified

- `bin/engine/tests/test_unit_path_shims.sh` — every house template that sets a PATH names the shims; the shims sit
  after `/usr/bin`; and the gate and the bridge are named on their own so a future edit that drops them fails with the
  file's name.
- `bin/gates/checks/unit-template-check.sh` — `systemd-analyze verify` reads all 28 templates clean.
- **Live on heimdall:** a drop-in (`hlidskjalf-gate.service.d/10-mise-path.conf`) mended the running unit, then
  `daemon-reload` and `restart`. The unit's own `/proc/<pid>/environ` PATH now ends with the shims and resolves
  `gh 2.103.3`; `GET http://127.0.0.1:3889/api/runtime` returns 200 and its digest no longer contains
  `gh is not installed`. Machine change recorded in `~/CHANGELOG.md`.
- Wired into `bin/gates/ci-verify.sh` as `unit-path-shims`.

## Not done here

`bifrost.service` carries the same PATH fault; it is mended by the pin flip rather than by a restart now, because its
provider fix lands in the same PR and a restart today would only re-raise the retired LM Studio door. The other
speaking units inherit the fix from the same templates the next time `fleet-ensure.sh` materialises them.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #750
