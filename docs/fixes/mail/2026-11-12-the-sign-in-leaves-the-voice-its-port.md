# mail · 2026-11-12 — the Google sign-in leaves the voice its port

## Files
- `bin/mail/gna_connect.py`: `connect_port()` reads `YMIR_OAUTH_LOOPBACK_PORT` (then `GNA_CONNECT_PORT`), default
  **8767**, no longer ephemeral; `port_holder()`; a busy port stops the sign-in with the holder named; the consent
  line says which redirect URI to register on a mismatch; self-test +1 (26/26)
- `systems/snotra/services/calendar/calendar-auth.sh`, `google-auth.sh`: the same setting, default 8767 (was 8765);
  the same busy-port refusal before listening
- `docs/features/connect-the-mail-and-calendar-door.md`, `docs/features/the-voice-engines.md`: appended sections

## Why
The operator, 2026-11-12, after a calendar sign-in had to stop Kokoro: *"were using kokoru to more things. we need
to make a plan for this"* (plan 276). Measured that evening: the sign-in's ephemeral port got `Error 400:
redirect_uri_mismatch` (the OAuth client is a Web client), and the port that works, 8765, is Kokoro's — the voice of
Hlidskjalf, Bilskirnir and Skírnir, and the house watch's probe. Two of the three sign-in doors defaulted to 8765.

## Proof
On nidavellir with Kokoro running: all three doors, pointed at 8765, refused with `port 8765 is held by kokoro
(pid …)` and Kokoro stayed active; `connect.sh google --no-browser` sent `redirect_uri=http://127.0.0.1:8767/callback`.

## Owed by the operator
Register `http://127.0.0.1:8767/callback` on the OAuth client in Google Cloud (or choose a Desktop-app client).

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
