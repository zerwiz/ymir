# An app reaches the world only behind the hall's login

**Component:** `forge` (`bin/forge/gjallarhorn-publish.sh`). **Date:** 2026-11-21.

## What was wrong

There was no safe way to reach an app from outside a machine. The tunnel door refuses any ingress at a hall port,
which is right, but it left an operator who wanted their own smithy on their own name with only a hand-edited
tunnel and nothing in front of it.

## What was changed

A new door, `bin/forge/gjallarhorn-publish.sh`, publishes an app by config alone. Its config lives in the
operator's home (`config/machines/<machine>/publish.yaml`); nothing about a name, a hall or an audience is written
in this repository.

- It refuses an app that names nobody, a gate that is not https, and an edge port that is a hall port.
- It raises a small Caddy edge on loopback whose every name asks the hall's `/oidc/authz`, and whose answer to any
  other name is 404.
- It asks the edge, as an unsigned browser, for every name, and stops before the tunnel or DNS is touched unless
  each is answered with a sign-in challenge.
- It extends the tunnel's ingress with a managed block ahead of the catch-all rule (idempotent, with a backup), and
  creates the DNS routes.
- `rules` renders the hall's per-app rules file from every machine's config, expanding `operator` from the home.

The tunnel guard (`gjallarhorn-tunnel.sh`) is unchanged: a tunnel still never dials a hall port. The published
name dials the edge, and the edge is the only road to the app.

## How it was proved

`bin/forge/tests/test_gjallarhorn_publish.sh` holds eight claims (empty audience refused, non-https gate refused,
hall-port edge refused, a gated config passes, forward-auth per name with a 404 default, dry-run writes nothing,
the block placed once ahead of the catch-all, rules expanded). `test_gjallarhorn_no_hall.sh` still passes. The
Gimlé side is a separate change (zerwiz/gimle#22).

## What is not done

Applying it on a machine is the operator's step, because it restarts that machine's tunnel.
