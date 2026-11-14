# No tunnel points at a hall

**Date:** 2026-11-14 · **Component:** forge (`bin/forge/gjallarhorn-tunnel.sh`, `midgard/infrastructure/ingress/`) · **Plan:** 275 item 30

## What was wrong

His word: *"this feature of opening online must go away with the logins we have. we are not hosting the 3 apps
online.. they are local. a collaborator found that were opening ports out."*

The halls already listen on loopback only (plan 279's fixes closed the open ports). What survived the hosted era was
**the tunnel**: `bin/forge/gjallarhorn-tunnel.sh` raised whatever its config said, and the config this repo shipped
(`midgard/infrastructure/ingress/cloudflared-ymir.yml`) published Hlidskjalf and Smíðja through
`http://127.0.0.1:3889` — a door to the gate, then a proxy to `:8437`.

## The fix

- **The script refuses a hall ingress.** Before cloudflared is even looked for, `start` reads every `service:` target
  in the tunnel config, takes its port, and refuses if it is a hall port:

  ```
  3888 Hlidskjalf SPA · 3889 the gate · 4322 Óðrerir · 8437 Smíðja ·
  8787 Bilskirnir · 4602 Mímir (the well) · 4603 Bifrost
  ```

  The refusal names the config line, the hostname, the service, the hall set, the law (plan 275 item 30) and the
  remedy. Only a scheme URL can dial a port, so `http_status:404` and `unix:` targets are skipped, not guessed at.
- **A `check` verb** audits a config without raising anything (exit 1 on a hall, and it counts the real ingress rows),
  so a seat can ask the question without starting a tunnel.
- **The shipped template publishes no hall.** `cloudflared-ymir.yml` is now a frontier template — one hostname, one
  surface that is meant to be public (the example is the video forge on `:8761`), everything else `http_status:404` —
  and it says in words that the halls are local and that a hosted, shared surface is a different product (plan 284).

## Verified

- `bin/forge/tests/test_gjallarhorn_no_hall.sh` — 6 checks: a config at the gate is refused and the refusal names the
  hostname, service and line; **every** hall port in the set is refused; a frontier surface (`:8761`, `:2586`, `:3891`)
  passes; `start` refuses a hall config before cloudflared is looked for; and no shipped ingress template publishes a
  hall.
- Measured on this seat: the tunnels that exist serve the video forge (`:8761`), the hound's notifications (`:2586`)
  and `:3891` — none of them a hall. No tunnel was started or stopped by this change.
- Wired into `bin/gates/ci-verify.sh` as `gjallarhorn-no-hall`.

## Not done here

The parts of item 30 that live inside the apps — the in-app login, `HLIDSKJALF_AUTH` and the halls chooser in
Hlidskjalf, and Smíðja's `HOST` pin — belong to errands `hall-follow` and `smidja-header-chat`. This change is the
tunnel guard the plan assigned to `bridge-and-rail`.
