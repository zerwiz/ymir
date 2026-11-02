# snotra · 2026-11-12 — google-auth uses the real vault and per-person grants

## Files
- `systems/snotra/services/calendar/google-auth.sh` — reads and writes through the vault doors; `--account`,
  `--grant-key`, repeated `--scope`

## Why
`google-auth.sh` was written against a home shape that no longer exists. It decrypted `platform.env.age` directly
and handed the refresh token to `/tmp/vault-put.sh`, a helper that does not exist. On a plain `platform.env` it
refused before printing a consent URL. There was also no way to give a second person their own grant, because the
destination key was hardcoded to `SNOTRA_GOOGLE_REFRESH_TOKEN`.

## Fix
- The client id and secret are read through `bin/vault/hodd.sh emit secrets/platform.env`, the one door for plain
  and age homes.
- The refresh token is written through `bin/vault/hodd-set.sh` (guarded, backed up, atomic) instead of the missing
  `/tmp` helper.
- `--account` sets `login_hint`, `--grant-key` names the person's token, and a repeated `--scope` adds Workspace
  scopes. `include_granted_scopes=true` lets a later Drive, Docs or Sheets consent extend the same grant.
- The script prints the URL and waits even without Chromium. The loopback listener is raised before the browser
  opens, so a fast redirect cannot race it.

## Verified
- `bash -n systems/snotra/services/calendar/google-auth.sh` passes.
- Against a temporary home with a dummy client, `google-auth.sh --url --account <address>` printed a consent URL
  with `login_hint`, four scopes, `include_granted_scopes` and PKCE. The live consent is the operator's step, so no
  token was created.

## CHANGE LOG

- **2026-11-12** — note written; the fix was carried over from the operator's fork onto upstream main.
