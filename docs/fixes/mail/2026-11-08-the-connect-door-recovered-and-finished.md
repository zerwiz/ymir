# The connect door, recovered and finished — the replay reproduced it, so nothing was rebuilt twice

**Component** `mail` · **Date** 2026-11-08 · **Plan** 221 (the connect door) · **Law** `RULES/06-append-only.md`

## What happened

The `connect-door-2` worktree was removed while its worker was still alive. A recovery commit rebuilt the
door from the worker's own session log — but a session log records **writes**, not the edits that followed
them, and three files were truncated or stale as a result: the recovered `bin/mail/gna_connect.py` ended at
`usage()` (no `main()`, no proofs), `hodd-set.sh` had neither `--stdin` nor `--del`, and the test and README
edits were absent.

Two things were true at once, and both matter:

1. **The work was not lost.** A duplicate pi pane in the same worktree had finished and committed it as
   `eindri/connect-door` (tip `c0e4c210`): the door, both documents, the fix note, the ledger fold, the
   registers, and the CalDAV measurement.
2. **The recovery could be proved rather than guessed.** The eight mutations the log recorded after the
   captured writes — two on `hodd-set.sh`, four on `gna_connect.py` (vault write and delete, the proofs
   section, the per-door self-test, the IMAP fixture's LOGIN parser), one on `tests/test_gna.py`, one on
   `README.md` — were replayed in order onto the recovered base. The result is byte-identical to the
   delivered branch but for one trailing newline and one feature-page section a later commit added.

So nothing had to be rebuilt twice. This note records the replay, the four measurements taken on the
finished door, and the one thing that was genuinely still missing.

## What was measured on the finished door

```
proof                                    command                                     result
the door's own proofs                    bin/mail/connect.sh --self-test             PASS — 25/25
the version answers, not silence         bin/mail/connect.sh --version               1.0.0
`who` is not a verb of this door         bin/mail/connect.sh who                     exit 2 + the full usage
the refusal, no client in the vault      connect.sh google, fixture home, no client  exit 3, three lines, no listener opened
```

The refusal is the one that mattered: with a real age vault that holds other keys but neither
`GOOGLE_MCP_CLIENT_ID` nor `GOOGLE_MCP_CLIENT_SECRET`, the door printed

```
connect: the fleet client is not in the vault — GOOGLE_MCP_CLIENT_ID and GOOGLE_MCP_CLIENT_SECRET are named and absent.
help: bin/vault/hodd-set.sh --set-stdin GOOGLE_MCP_CLIENT_ID  (paste the value on stdin)
help: this is phase C0 of plan 221 — ONE Cloud project, consent screen Internal, one OAuth client marked 'Use this client for an AI-powered agent'
```

and exited 3. No consent URL, no browser, no loopback socket: the listener is constructed only after the
client resolves from the vault, so a door with no client cannot half-open.

`who` is answered by saying what is true — it is **not** a verb of this door, it appears in no help text,
and `connect.sh who` refuses with the usage and exit 2 rather than printing nothing. The recovery's silence
on `--version` and `who` was one fault, not two: the file had no `main()`.

## The CalDAV question: an app password cannot drive it — NO

Re-measured on 2026-11-08, so the plan's answer is a measurement and not a quotation:

```
request   PROPFIND https://apidata.googleusercontent.com/caldav/v2/
          Depth: 0 · Content-Type: application/xml
          <propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>
auth      Authorization: Basic <base64("someone@example.com:abcdefghijklmnop")>

response  HTTP/2 401 · content-type: application/vnd.google.gdata.error+xml
          <error><domain>GData</domain><code>loginRequired</code>
                 <internalReason>Login Required.</internalReason></error>
          and NO `WWW-Authenticate` header at all
```

The same body with `Authorization: Bearer <junk>` answers **`401 invalidCredentials`** — a different code,
because the bearer is *read and refused* while the Basic credential is not read at all. A server that
advertises no Basic challenge does not speak that scheme; that is the distinction, and it is the whole
answer. (Google's own CalDAV guide says the same in words; this is the byte-level confirmation.)

**So the guest road (T2) is mail-only, and the calendar stays OAuth.** That is recorded in the door's own
fix note, in the README's appended section, and in plan 221's append — one answer, in three places a reader
actually looks.

## What was genuinely missing: nothing in the door — and the registers were already current

The door needed no finishing, so the honest answer to "what was missing" is: only the record of the
recovery. `bin/gates/guards.sh` on the adopted tree named `inventory-guard` (`bin/mail/INDEX.md` stale), so
`bin/gates/inventory.sh` and `bin/gates/registers.sh generate` were run — and both **reproduced the delivered
values byte for byte**: `connect.sh` with 3 callers and 71 lines, `gna_connect.py` with 3 callers and 1434
lines, `ledger.sh` at 279 lines, and the `connect.sh` row already present in the mail capabilities fragment.
The delivered branch had regenerated its registers before committing; the guard's reading came from the
recovered base this branch started on, not from the delivered tree.

So this branch's only content change against `eindri/connect-door` is this note. `bin/gates/guards.sh`
reports **CLEARED**: the two wards still red (`defaults-guard`, `desktop-main-guard`) are red on
`origin/main` as well — four launchers pointing into a worktree and one default that no change of ours
touched.

## Owed

- **The registers land here; the door already landed on `eindri/connect-door`.** This branch carries the
  delivered tree plus the regenerated registers, so merging it must not be read as a second door.
- **`a2a` / desk surfaces unchanged.** The desk (`:8494`) and the one mail record (`ledger.sh tail`, which now
  folds this door's log) were verified by their own tests, not by this note.
- **One hand still owed outside code:** phase C0 — the fleet's OAuth client — is the Allfather's to mint in
  the Workspace console. Until then every user's `connect.sh google` refuses in the words above, which is
  the designed behaviour and not a fault.

## CHANGE LOG

- **2026-11-08** — first cut: the replay that reproduced the delivered door, the four measurements
  (self-test 25/25 · `--version` · the refusal · `who` is not a verb), the CalDAV answer re-measured with its
  exact request and response, and the finding that the registers were already current (the regeneration
  reproduced them exactly, so this branch adds only this note to the delivered tree).
