# The publish edge matches each app, and names it to the gate

**Component:** forge · **Date:** 2026-11-21 · **PR:** #882

## What was wrong

- The edge site was written `http://127.0.0.1:<port>`. Caddy reads that address as a host matcher for `127.0.0.1`, so the per-app host routes never matched. Every published name got Caddy's empty 200, and `apply` could never publish.
- The forward-auth asked the gate `/oidc/authz` and relied on `X-Forwarded-Host`. The hall's edge rewrites that header to its own name, so the gate found no per-app rule. It fell back to the hall rule, which let every gate user in. That failed open.

## What changed

- The site is `http://:<port>` with `bind 127.0.0.1`, so it is still loopback only and each app's host route matches.
- Each forward-auth asks `/oidc/authz?app=<host>`, so the gate judges the app's own rule. The gate accepts `?app=` only under the house domain.
- `bin/forge/tests/test_gjallarhorn_publish.sh` now runs the rendered Caddyfile through `caddy adapt` (a local caddy or the `caddy:2-alpine` image). It asserts that there is no loopback host matcher, that each app has its host route, and that each auth names its app. The check is skipped cleanly when neither caddy nor the image is present.

## Proof

`bash bin/forge/tests/test_gjallarhorn_publish.sh` gives 9 ok / 0 fail.
