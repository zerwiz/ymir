# Dex, the issuer the door trusts — Google and GitHub behind one login

**Component:** `gimle` (the Dex deployment, `bin/gimle/mcp/dex/`).
**Date:** 2026-11-19. **Plan:** plan 149, *the identity providers*.

## What was wrong

The ask was to let people log in with Google and GitHub. The suite's existing identity service, Authelia,
cannot do that. It supports the OpenID Connect Provider role only, never the Relying Party role that a
federated login needs (authelia/authelia issue #2728). Configuring it harder would not have helped.

## What was changed

Dex is deployed as its own compose service with its own state, and it is the issuer the MCP door trusts.
Authelia stays where it works: the web halls' forward-auth.

| File | What it holds |
|---|---|
| `bin/gimle/mcp/dex/docker-compose.yml` | Dex `v2.41.1`, published on loopback only, state in `./state` |
| `bin/gimle/mcp/dex/config.example.yaml` | the GitHub and Google connectors, the door's two clients (`gimle-mcp` confidential, `gimle-mcp-cli` public), a commented stand-in connector for a dry run |
| `bin/gimle/mcp/dex/dex.env.example` | where each provider id and secret goes, as placeholders |

Two facts were measured on v2.41.1 and are written into the config:

- Dex expands `$NAME` only inside connector configs. An environment variable in `issuer:` stays literal
  text, so the issuer and the callbacks are written into `config.yaml` directly.
- A public client may call back to `http://localhost:<port>` but not to `http://127.0.0.1:<port>`
  (`Unregistered redirect_uri`).

## How it was proved

`python3 bin/gimle/mcp/test_dex_login.py` raises the shipped config in docker with the stand-in connector
switched on. A real authorization-code login with PKCE through `gimle-mcp-cli` is admitted by the door with
subject and road right. A login through the confidential `gimle-mcp` (its secret read via `secretEnv`) is
admitted too. A token Dex issued to another client is refused with the reason logged. The container is
removed afterwards.

## What is not done

The GitHub and Google OAuth apps are the operator's to create in their own consoles. Until they exist, a login
with that provider fails at the provider and nothing else waits. Publishing Dex on the tunnel is also the
operator's step.

## Added the same day — Dex runs as the owner of its state

The compose file first defaulted to the image's own uid (1001), which cannot write a `state/` directory made
by the host user. The documented command now passes `DEX_UID=$(id -u) DEX_GID=$(id -g)`. Measured with
`docker compose up -d` in a scratch directory: `state/dex.db` appeared and the issuer answered.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #826
