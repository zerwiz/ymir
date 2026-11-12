# Connect your mail — one sign-in, or three fields

**What it is.** A door that takes you from "I have a Google account" to "this machine can read my mail",
without opening a cloud console. Two roads:

- **One button** — you sign in to Google once, and the machine keeps a grant of its own in your vault. Mail,
  drafts and calendar permissions come with it.
- **Three fields** — you type your address and an app password, and mail reading works the same afternoon.
  No Google sign-in, no cloud project.

The same door is also the honesty line: it can tell you at any moment whether an account can still be
**read**, whether it may **send** (it may, but only through our gate), and whether mail can actually
**arrive** at the domain.

**What you need**

- For the one-button road: a Google account inside the Workspace organisation, and the fleet's OAuth client
  already in your vault (`GOOGLE_MCP_CLIENT_ID` and `GOOGLE_MCP_CLIENT_SECRET`). Your operator sets that up
  **once** for everyone — you never create a cloud project.
- For the three-field road: a Google account with **2-Step Verification** on, so Google will issue an **app
  password** (Google Account → Security → App passwords). A normal password is refused by IMAP.
- Nothing else. No token is ever typed into a file by hand, and no password is ever echoed back.

**The commands**

```sh
bin/mail/connect.sh google            # one button: it prints a URL, you sign in, it waits for the redirect
bin/mail/connect.sh google --check    # is my grant still alive, and when does it expire
bin/mail/connect.sh imap --address me@example.com    # three fields; it asks for the app password
bin/mail/connect.sh status            # per account: readable · sendable · deliverable
bin/mail/connect.sh revoke me@example.com            # revocation, as a verb
bin/mail/connect.sh --self-test       # 25 proofs, offline — no network, no real account
```

Each verb answers with a measurement, not a promise:

```
account me@example.com · grant live · expires 2026-11-08T21:36:26Z
mailbox me@example.com · INBOX · 7 messages
accounts[2]{account,transport,readable,sendable,deliverable,grant,checked,detail}:
  "me@example.com","google","yes","yes (our gate)","yes","live","2026-11-08T20:36:28Z","…"
```

**The limits — read these as promises**

- **Sending is not here.** Mail leaves only through the letters gate
  (`systems/snotra/services/letters/mail-send.sh`), where your approval is bound to the exact bytes of the
  letter. This door can read, and it can tell you whether the grant *could* send — it has no send path at all,
  and a proof fails if one appears.
- **A dead grant is never an empty inbox.** `--check` says `grant dead: invalid_grant`. If you see an empty
  queue and no such line, nobody has checked; run it.
- **An app password gives you mail, not calendar.** Google's CalDAV server refuses Basic authentication
  outright (measured 2026-11-08: `401` with `code loginRequired`, no `WWW-Authenticate` challenge), so a guest
  calendar needs the OAuth road or nothing.
- **No address is assumed.** The IMAP host default is derived from your address and printed before it is used
  (`--host` overrides); the port is 993 unless you say otherwise; an unencrypted session off loopback is
  refused.
- **No secret is printed, and none is written into this repo.** Values live in the home's vault under key
  names; the register (`hodd/memory/mail/accounts.yaml`) names the keys and never the values. The app password
  is read on stdin, so it does not appear in a process listing.
- **Deliverability is measured, not assumed.** `status` reads the same register that
  `bin/mail/addresses.sh --check` uses; a domain with no MX record is reported undeliverable, however green the
  rest of the row looks.

**If it does not work**

- *"the fleet client is not in the vault"* — the operator has not finished `C0`: one Cloud project, consent
  screen **Internal**, one OAuth client marked *Use this client for an AI-powered agent*. The door names the
  two keys it wants and stops; it never guesses a client.
- *`no grant — state_mismatch`* — two sign-ins were open at once. Run the verb again with nothing else waiting.
- *`grant dead: invalid_grant`* — the grant was revoked, or a Testing-status client's grant expired (Google
  expires those after seven days). Run `connect.sh google` again; the check is what tells you, before you
  wonder why the inbox is quiet.
- *`imap: LOGIN refused … [ALERT] Invalid credentials`* — the password was a normal Google password, or 2-Step
  Verification is off, or the admin forbids app passwords. Nothing was stored.
- *`sendable: no — the grant carries no gmail.send`* — the grant predates the send scope. Sign in once with
  `connect.sh google`; it asks for the send scope, and sending still only happens at the gate.
- *Revoked by mistake?* — run `connect.sh google` (or `imap`) again. The register row is left in place, so a
  re-connect reuses the same key names.

**Where it lives**

`bin/mail/connect.sh` (the door) · `bin/mail/gna_connect.py` (the verbs, the loopback catcher, the proofs) ·
the register `$YMIR_HOME/hodd/memory/mail/accounts.yaml` · the event log
`$YMIR_HOME/hodd/memory/mail/connect-log.jsonl` · the vault through `bin/vault/hodd.sh` /
`bin/vault/hodd-set.sh`. Plan 221 is the design; `docs/fixes/mail/2026-11-08-the-connect-door.md` is what was
measured while building it.

**One record of what happened to your mailbox**

`bin/mail/ledger.sh tail` shows the letters that went out and came in — and, folded in from the connect
door's own log, every grant made and every grant revoked. So one command answers "what has this mailbox
done", and a door that was opened or shut can never hide behind a quiet inbox.

```
bin/mail/ledger.sh tail 20      # letters + grants, newest last, one row each
bin/mail/ledger.sh digest       # counts per day, both directions
```

The two files stay separate on disk because they are written by different hands and are each append-only
(Rule 06); one of them is never rewritten to fold the other in. The reading is what is shared.

**A guest gets mail, not a calendar**

An app password opens IMAP, POP and SMTP. It does **not** open Google calendar: the CalDAV endpoint refuses
Basic authentication outright and demands OAuth 2.0 (asked on 2026-11-08, answered by a `PROPFIND` that came
back `401 loginRequired`, with no Basic challenge offered at all). So the three-field road is mail-only, and
nothing in this house promises a guest a calendar. A guest's calendar is a Workspace seat and one sign-in.


## The sign-in port, and Kokoro

Google signs you in by sending your browser back to a small local listener. The fleet's OAuth client is a **Web**
client, so Google only accepts return addresses registered on it. A random port gets `Error 400:
redirect_uri_mismatch`.

- Every Google sign-in reads one setting: **`YMIR_OAUTH_LOOPBACK_PORT`**, default **8767**. This covers
  `connect.sh google`, `calendar-auth.sh` and `google-auth.sh`. The older `GNA_CONNECT_PORT`, `CALENDAR_AUTH_PORT`
  and `GOOGLE_AUTH_PORT` are still read under it.
- **Port 8765 belongs to Kokoro**, the house's voice. No sign-in uses it by default.
- **Register the address once.** In Google Cloud, open APIs & Services → Credentials → the OAuth client → *Authorized
  redirect URIs*, and add `http://127.0.0.1:8767/callback`. Until that's done, the sign-in shows Google's mismatch
  error. The terminal prints the exact address to add.
- **A busy port is reported, never worked around.** If something already listens on the port, the sign-in names it
  (`port 8767 is held by <program> (pid N)`) and stops. It never stops a service.

```bash
bash bin/mail/connect.sh google --account you@example.com             # signs in on 8767
YMIR_OAUTH_LOOPBACK_PORT=8768 bash bin/mail/connect.sh google ...     # another registered port
```

## CHANGE LOG

- **2026-11-08** — First cut: the four verbs, the two roads (one sign-in, three fields), the limits that are
  promises, and the failure lines a person actually sees.
- **2026-11-08 (appended)** — Added how to read the one mail record (`ledger.sh tail` now folds the connect
  events in) and the CalDAV answer, so the page never leaves a guest expecting a calendar it cannot have.
- **2026-11-12** — Appended: one sign-in port off Kokoro's 8765; a busy port is named; the mismatch explained (plan 276).
