# The connect door — four verbs, one sign-in, and the CalDAV question measured

**Date:** 2026-11-08 · **Plan:** 221 §4–§5 (`svartalfaheim/whynotproductions/projects/ymir/plans/221-the-connect-door.md`) · **Law:** `RULES/07-config.md` (no hardcoded host, port or credential) · `RULES/06-append-only.md` (the register is added to, never rewritten)

## What was wrong

His word: *"its is way way too complicated for new users to set up their email and google calendar … cant we
utilize the mcp google provide more?"* Plan 221 answered the MCP half — Google's MCP is real, is harder for a
user rather than easier, and cannot send (`gmail.readonly` + `gmail.compose`, no `gmail.send`). The half that
was still missing was **a door**: there was no command that took a person from "I have a Google account" to
"this machine can read my mail", and no command that told the truth about a grant that had quietly died. The
desk showed an empty inbox for a dead grant, which is the same screen a quiet day shows.

## What was built

`bin/mail/connect.sh` (wrapper) over `bin/mail/gna_connect.py` (the door). Four verbs, each ending in a
measurement:

| verb | what it does | the measurement it ends with |
|---|---|---|
| `google` | consent URL → loopback redirect on `127.0.0.1` (ephemeral port by default) → code exchanged → the refresh token written to the vault **by key** | `account <address> · grant live · expires <t>`, from one `GET /users/me/profile` |
| `google --check` | the boot check, per account | `grant live · expires <t>`, or `grant dead: invalid_grant — …` |
| `imap` | address + app password (read on **stdin**, never argv) | a real `LOGIN`, a real `EXAMINE`, and `mailbox <addr> · INBOX · <n> messages` |
| `status` | per account, per the register | `readable · sendable · deliverable`, and `counts{…}` |
| `revoke <account>` | the vault key goes dark | `stopped[3]{what,why}` — what stopped and why, per surface |

Each verb carries `--self-test`; `connect.sh --self-test` runs all 25 proofs. They run offline against
fixtures on loopback: a token door, a tokeninfo door, `GET /users/me/profile`, a fixture IMAP server that
speaks greeting · `CAPABILITY` · `LOGIN` · `EXAMINE` · `LOGOUT`, and a **real age vault** in a temp home
(`age-keygen` + `hodd-set.sh`), so the write path proved is the shipped one.

`bin/mail/connect.sh --self-test` → **25/25 PASS**, including: the consent URL carries `access_type=offline`
and `prompt=consent` and no secret; a mismatched `state` is refused and writes nothing; the refresh token
resolves through `hodd-set.sh --get` afterwards; neither the token nor the client secret appears in stdout or
stderr of any verb; `--check` says `grant dead` and never mentions messages; a wrong app password fails in one
line and stores nothing; `revoke` darkens the key and `status` then says `readable=no`.

## Live, on this seat

```
$ bin/mail/connect.sh google --check
account <the operator's mailbox> · grant live · expires 2026-11-08T21:36:26Z

$ bin/mail/connect.sh status
accounts[1]{account,transport,readable,sendable,deliverable,grant,checked,detail}:
  "<the operator's mailbox>","google","yes","no — the grant carries no gmail.send","yes","live",…,"1 aspmx.l.google.com, …"
```

`python3 bin/mail/tests/test_gna.py` → **37 tests, OK** (36 before; the new one is below).

## The finding that costs the gate its send

The register's row for the operator's own mailbox said, measured 2026-10-23, that the grant carries *gmail.readonly ·
gmail.compose · gmail.send · calendar.events*. Measured **from the token itself** on 2026-11-08
(`oauth2.googleapis.com/tokeninfo`, through `refresh_token`):

```
email · openid · userinfo.email · gmail.readonly · gmail.compose
drive.file · drive.readonly · documents · documents.readonly
```

**No `gmail.send`, and no `calendar.events`.** So `mail-send.sh` cannot send with this grant (it calls the
`send` endpoint), and calendar reads would be refused. That is why `status` prints
`no — the grant carries no gmail.send` instead of a comfortable green. The fix is the button: `connect.sh
google` asks for readonly + compose + **send** + calendar.events, so one sign-in re-mints the grant with the
authority the gate and the calendar need. The register's old `measured:` line is left as written (Rule 06) —
the correction is this note and the plan's append.

## The CalDAV question, answered: NO

**Can a Google app password drive CalDAV, so a guest has a calendar without OAuth? No.** Measured, not read:

```
request:  PROPFIND https://apidata.googleusercontent.com/caldav/v2/
          Depth: 0 · Content-Type: application/xml
          <propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>
auth:     Authorization: Basic <base64("someone@example.com:abcdefghijklmnop")>
response: HTTP/2 401 · content-type: application/vnd.google.gdata.error+xml
          <error><domain>GData</domain><code>loginRequired</code>
                 <internalReason>Login Required.</internalReason></error>
```

`loginRequired` — with **no `WWW-Authenticate: Basic` challenge at all**, which is how a server says the scheme
is not one it accepts. The same request with a bearer token is parsed as OAuth and refused for a different
reason (`401 invalidCredentials`), and an unauthenticated `OPTIONS` answers `200` (DAV capabilities only). The
contrast with the mail door is exact: `imap.gmail.com:993` greets `* OK Gimap ready`, advertises
`AUTH=PLAIN AUTH=XOAUTH2`, and refuses a bad credential with `NO [ALERT] Invalid credentials (Failure)` — a
credential door, not a scheme it does not speak.

Google says the same in its own words (`developers.google.com/workspace/calendar/caldav/v2/guide`): *"The
CalDAV server refuses to authenticate a request unless it arrives over HTTPS with OAuth 2.0 authentication of
a Google Account. Attempting to connect over HTTP or using Basic Authentication results in an HTTP 401
Unauthorized status code."*

**So the guest road (T2) is mail-only, and plan 221 records it that way.** A guest's calendar is OAuth or
nothing: joining the Internal client's domain, or an app password plus a mail-only desk.

## One law had to be re-read on purpose

`bin/mail/tests/test_gna.py` carries `NoSendCapability`, which forbade the strings `gmail.send` and
`mail-send.sh` anywhere in `bin/mail/`. A door that **mints** a grant must be able to name the authority it
asks for, and must be able to say where sending really happens, or a reader is left believing it happens here.
The guard is now split and no weaker in the part that matters:

- `FORBIDDEN` (every file, always): `messages/send`, `smtplib`, `users/me/drafts` — the real send paths.
- `VOCABULARY` (`mail-send.sh`, `gmail.send`): allowed only in `gna_connect.py`, and only because a second
  proof refuses any line that names sending **and** carries a transport call
  (`urlopen|_post_form|_get_json|curl|subprocess|smtp`). The door also proves its own innocence
  (`--self-test`: "no send path exists in this file — sending stays on the gate").

Sending still happens only at `systems/snotra/services/letters/mail-send.sh`, where the operator's word is
bound to the exact RFC822 bytes (plan 221 §4).

## What else moved

- `bin/vault/hodd-set.sh` gained `--stdin` and `--del`: a token must not ride argv (it would sit in `ps` and in
  a shell history), and revocation needs to remove a key rather than shadow it with an empty value. `--del`
  refuses to empty the vault and exits 3 when the key is already absent.
- `bin/mail/gna_connect.py` inserts a **new** row into `hodd/memory/mail/accounts.yaml` and never rewrites an
  existing one; the new text is parsed with the same loader the store uses before it replaces the old file, and
  a parse that loses an account is a refusal.
- `hodd/memory/mail/connect-log.jsonl` is the append-only event log: every connect and revoke, one line. A
  revocation is an **event**, so `status` reads it instead of the register being edited to say so.
- `deliverable` is `bin/mail/addresses.sh`'s own register (`gna_addresses.register()` / `mx_state()`), not a
  second DNS implementation.

## Owed, and named

- **C0 is the operator's**: one Cloud project inside the Workspace organisation, consent screen **Internal**,
  one OAuth client marked *Use this client for an AI-powered agent*, and `GOOGLE_MCP_CLIENT_ID` /
  `GOOGLE_MCP_CLIENT_SECRET` in the vault. The door refuses in one line, naming those keys, until then.
- **A Web-app client must pin the port** (`--port` or `GNA_CONNECT_PORT`), because Google matches the redirect
  URI exactly; a Desktop-app client accepts the ephemeral port this door uses by default. The choice is C0's.
- **The grant needs one re-consent** before the gate can send or the calendar can be read (no `gmail.send`, no
  `calendar.events` today).
- **B0 is untouched**: `bin/mail/addresses.sh --check` still reports 6 undeliverable (no MX for `zerwiz.org`,
  two missing Workspace aliases). That is the Allfather's hand, and no code here pretends otherwise.

## CHANGE LOG

- **2026-11-08** — First cut: the four verbs with their proofs, the live `--check`/`status` on this seat, the
  measured scope finding (no `gmail.send`), the CalDAV answer with its exact request and response, the send
  guard split with its reason, and the four owed items.
- **2026-11-08 (correction, appended)** — the operator's own address was printed three times in the section
  above. It is personal data: it belongs in the home, and a public fix note may say *the operator* and nothing
  more (RULES/04, and the same correction made on 2026-11-03 in `unversioned-2026-10-23-the-ward-read-a-message-as-code.md`).
  Redacted in place, above; the measurement and the finding are unchanged, and `bin/gates/guards/public-data-guard.sh`
  now reports no finding in this file.
