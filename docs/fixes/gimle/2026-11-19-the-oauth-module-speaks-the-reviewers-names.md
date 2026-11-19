# The OAuth module speaks the reviewer's names

**Component:** `gimle` (`bin/gimle/mcp/gimle_oauth.py`, `gimle-mcp.py`).
**Date:** 2026-11-19. **Plan:** plan 149.

## What was wrong

The reviewer's tested diff and this branch built the same resource server under different names. Two sets of
names for one door would not reconcile when the batch is gathered.

## What was changed

- `gimle_oauth.OAuth(issuer, resource, introspect_client, introspect_secret, allowed_clients,
  write_group='gimle-write', place_prefix='gimle-place-', all_group='gimle-all', ttl=60)` is now the class the
  door builds. It wraps the existing `ResourceServer`; nothing about validation changed.
- The three group names are configurable, through the class and through `--oauth-write-group`,
  `--oauth-place-prefix` and `--oauth-all-group`.
- The introspection secret's default path is `/etc/gimle/oauth-introspect-secret`. Creating it needs `sudo`
  on the heart, so it is documented as the operator's step and never done by a worker.
- Names that already matched are unchanged: `CANVAS_WRITES` at module level, `--oauth-issuer`, `405` on
  `GET /mcp`, and the refusal of a token from an issuer client outside `allowed_clients`.

## How it was proved

`test_oauth_door.py` gained test 14. It builds `OAuth(...)` with the reviewer's signature and custom group
names, checks the prefix mapping and the write group, and checks that a token issued to a client outside
`allowed_clients` is refused. Result: `14 passed, 0 failed`. `test_dex_login.py` against a real Dex: `all green`.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #826
