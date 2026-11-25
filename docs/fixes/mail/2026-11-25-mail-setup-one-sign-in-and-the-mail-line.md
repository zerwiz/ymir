# Mail setup is guided, one sign-in serves mail and calendar, and one line says the mail is alive

**Date:** 2026-11-25 · **Component:** the connect door (`bin/mail/connect.sh`, `bin/mail/gna_connect.py`), the
calendar sign-in (`systems/snotra/services/calendar/calendar-auth.sh`), the calendar reader, the Sága head and the
trouble panel · **Rules:** 04, 06, 07 · **Plan:** 375 (B2 and B5, chosen after B0 to B5 were measured)

## The fault

The operator's complaint was that connecting mail is too hard for a person. Measuring the road found three things behind it:

- **Five console pages with no feedback.** Nothing said whether the Cloud project, the APIs, the consent screen, the
  client and its redirect address were right until a sign-in failed.
- **Two grants and three sign-in commands for one person.** `calendar-auth.sh` ran its own sign-in and wrote
  `MANAGANDR_OAUTH_REFRESH_TOKEN` into the vault by decrypting and re-encrypting it by hand. That made it a second
  writer of the vault, and it once wrote an empty vault (2026-11-07). Its scope, `calendar.events`, is already inside
  the connect door's grant.
- **A dead grant was seen only when someone ran `--check`.** Nothing in the digest or the trouble panel looked.

A fourth was found while building: **the fleet client accepts only `http://127.0.0.1:8765/callback`**. That is Kokoro's
port, which plan 276 moved every sign-in away from. So `connect.sh google` on the default 8767 answers
`redirect_uri_mismatch` today.

## What changed

- **`connect.sh setup`**: a guided first run in four steps, each measured before the next.
  1. The client: it opens the console pages, and the two values are pasted and sealed through `hodd-set.sh`.
  2. The return address: Google is asked about it without signing anyone in. The 302 to `/signin/oauth/error`
     carries the reason in `authError`; a registered address goes on to the sign-in page.
  3. One sign-in, through `cmd_google`.
  4. The APIs: Gmail through `/users/me/profile`, Calendar through `calendarList`.

  `--check` measures and changes nothing, `--again` signs in afresh and `--new-client` replaces the client.
- **`connect.sh google --print-url`** prints the consent URL with nothing listening. It keeps what
  `calendar-auth.sh --url` always did.
- **`calendar-auth.sh` 2.0.0** runs the connect door's sign-in instead of its own. It still opens the
  `CHROMIUM_PROFILE` profile and still reads `CALENDAR_AUTH_PORT`. It no longer writes the vault by hand. The old grant
  is not deleted.
- **One grant first.** `tools/calendar/reader.mjs` (`refreshKeyOf`) and `bin/voice/voice_tools.py` read
  `SNOTRA_GOOGLE_REFRESH_TOKEN` (or `YMIR_GATE_GRANT_KEY`) when present, and otherwise the older
  `MANAGANDR_OAUTH_REFRESH_TOKEN`. A named `MANAGANDR_OAUTH_KEY` still wins.
- **`connect.sh line`**: one line on the mail. `check`, `status` and `setup` keep the last measurement in
  `$YMIR_HOME/state/mail/connect-status.json`, which holds liveness and detail only, never a token.
  - The Sága head prints `line --cached`, which never asks Google.
  - The trouble panel has a `mail` signal, measured hourly (`TROUBLE_MAIL_S`), with a button.

Nothing here can send. The connect door's own proof that it has no send path still holds, and mail to anyone but the
operator still leaves only through `systems/snotra/services/letters/mail-send.sh`.

## Proof

| Proof | Result |
|---|---|
| `bin/mail/connect.sh --self-test` | **40/40**: the 26 that stood, unchanged, plus 9 for setup and 5 for the line |
| the same, five runs in a row | 40/40 each time. An earlier run failed 2 of them now and then: `line --max-age 0` treated a reading from the same second as fresh. Fixed: `--max-age 0` always measures |
| `bin/mail/tests/test_gna.py` | 49/49 |
| `test_draft_age.py` · `test_headers.py` · `test_threads.py` | 16 · 19 · 23, OK |
| `systems/snotra/services/calendar/tests/test_calendar_write.sh` | every proof held |
| `bin/time/snotra/tests/test_outbound_gate.py`, in its repaired form (branch `eindri/letters-gate-test`) | 16/16 |
| `.agents/tests/managandr-reader.test.sh` | all checks passed |
| `bin/ward/tests/test_trouble.sh` | all passed, including three new `mail` proofs |
| `saga-session-start.sh --check` | the head fits: 55 of 60 lines |

Measured live on the dev machine, read-only:

- The calendar was read from Google with **only** the one grant in the environment: `ok google 65` events.
- `setup --check` on port 8767 stops at step 2 with `redirect_uri_mismatch` and the address to add.
- With `YMIR_OAUTH_LOOPBACK_PORT=8765`, every step is ✔ and the run ends `result: READY`.
- `trouble.sh read --only mail` printed `ok — 1 account(s) readable`.

## What is still owed

- **The operator, in the Google console:** add `http://127.0.0.1:8767/callback` to the fleet client's Authorized
  redirect URIs. Until then, `connect.sh google` and `setup` need `YMIR_OAUTH_LOOPBACK_PORT=8765`, which is Kokoro's
  port.
- **Optional, once the one grant is proved in daily use:** `connect.sh revoke` cannot darken the old
  `MANAGANDR_OAUTH_REFRESH_TOKEN`, because it is not a register row. Removing it from the vault is the operator's
  choice.
