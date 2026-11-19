# The MCP door learns OAuth: a login, not a hand-minted token

**Component:** `gimle` (the MCP door, `bin/gimle/mcp/gimle-mcp.py`, and its new `gimle_oauth.py`).
**Date:** 2026-11-19. **Plan:** plan 149, *the door that logs its people in*, in the operator's home.

## What was wrong

The door admitted only static tokens from a file. A missing token answered `401 {"error": "a Gimlé token is
required"}` with no `WWW-Authenticate` header, and there was no `/.well-known/oauth-protected-resource`. A
client that speaks the MCP authorization spec therefore had nothing to start a login with. Every token was
minted by hand and lived forever, and the ledger could not say how a caller had come in.

## What was changed

| Change | Where |
|---|---|
| An OAuth 2.1 resource server, standard library only: JWT checked against the issuer's JWKS (RS256/384/512) or RFC 7662 introspection, an audience check, `userinfo` for the subject and groups, a 60 s cache | `bin/gimle/mcp/gimle_oauth.py` |
| `--oauth-issuer` and its sibling flags; `/mcp` accepts an OAuth token or a static one, the bearer file asked first | `gimle-mcp.py` |
| `401` carries `WWW-Authenticate: Bearer resource_metadata="…"`; the metadata document names the issuer | `gimle-mcp.py` |
| `GET /mcp` answers `405` with `Allow: POST` | `gimle-mcp.py` |
| Groups decide scope: `gimle-all`, `gimle-place-<Name>`, `gimle-write` (and only on an `--allow-write` door); no place group means no places | `gimle_oauth.scope_from_groups`, `CallerView` |
| Every ledger line names its `road`: `bearer-file`, `oauth` or `none`, and an OAuth line its `client` | `State.record` |

The subject is `preferred_username`, then `email`, then `sub`. The plan named `sub` as the fallback; `email`
sits between because Dex's `sub` is an opaque encoded id that reads as nothing in an audit line.

## How it was proved

- `python3 bin/gimle/mcp/test_oauth_door.py` — the plan's eight tests and five more, against a stand-in
  issuer that signs real RS256 tokens: `13 passed, 0 failed`, no door left listening.
- `python3 bin/gimle/mcp/test_dex_login.py` — the shipped Dex config raised in docker, a real PKCE login
  admitted with the right subject and road, a confidential-client login admitted, another app's token
  refused: `all green`.
- On the heart, the new door on a spare port with the real token file and the real board: static token
  `200` with `36` tools, unauthenticated `401` with the header, metadata `200`, `GET /mcp` `405`. The live
  door was not touched; it still answered `200` with `36` tools.

## What is not done

The door's unit on the heart still runs the old file. Copying the two files in, the `/etc/gimle` directory,
the unit's flags and the restart are the operator's hand; `bin/gimle/mcp/README.md` states each command.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #826
