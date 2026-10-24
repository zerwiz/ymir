# Gná — the one mail desk (production)

**Gná** carries word and brings it back: she is the secretary who reads the accounts
she is scoped to, judges what a message is, and puts it in a queue with a proposed
action and the evidence for it. **She cannot send** — there is no send path in this
directory, and a test fails if one appears.

Law: plan 116 (`svartalfaheim/whynotproductions/projects/ymir/plans/`, in the home).
Page: `docs/features/gna-the-one-mail-desk.md`.

## What is here, and what is private

```
bin/mail/gna_store.py     the store: an account is the boundary; a read without one is refused
bin/mail/gna_judge.py     the judge: six classes · six actions · rules only · evidence always
bin/mail/gna_import.py    the importer: the Gmail API, read-only, one account, --dry-run
bin/mail/gna_desk.py      the desk: 127.0.0.1:8490, token + account scope, GET only
bin/mail/mail-scan.sh     the earlier one-shot read (kept — it proved the door opened)
bin/mail/install.sh       seats the desk as a systemd USER unit, restart-always
bin/mail/tests/           16 proofs, including "no file here can send"
```

The **store and the scope never live here**: they are the home's
(`$YMIR_HOME/hodd/memory/mail/` — `accounts.yaml`, `retention.yaml`,
`messages.jsonl`), and the message spine is git-ignored. Schema, scope and
retention travel; raw mail does not.

## Install and run

```sh
bash bin/mail/install.sh                 # unit: gna-desk.service, enabled, /health proven
bash bin/time/nornir-job-gna-mail.sh --check     # is the desk answering?
bash bin/time/nornir-job-gna-mail.sh --dry-run   # read the mailbox, write nothing
bash bin/time/nornir-job-gna-mail.sh             # import, then prove the desk
python3 bin/mail/tests/test_gna.py               # the proofs
```

The schedule is a Nornir row in the home's `config/cron.yaml`
(`bin/time/nornir-job-gna-mail.sh`), never an absolute path to one machine.

## The four columns

| Column | Meaning | Human act |
|---|---|---|
| **Needs you** | judged, an action proposed, nothing sent | approve · change · dismiss |
| **Unsure** | low confidence, or a sender the book does not know | assign · teach · dismiss |
| **Waiting** | outbound, no answer yet | nudge · close |
| **Done** | a notice recorded, or bulk mail that asked nobody anything | read only |

Every row carries `evidence`: the rule **and the word** that fired.

## The laws, in code

- **No send capability.** No SMTP, no draft creation, no Gmail send endpoint.
  `tests/test_gna.py::NoSendCapability` scans every file here.
- **An account is the boundary.** `require_account()` refuses a blank account and an
  account not declared in the scope file; `get_message()` refuses a message from
  another account's scope. The desk answers 400, not an empty list.
- **Absence is a failure.** `/health` reports counts, the last ingest and the
  declared scope; `nornir-job-gna-mail.sh` writes a FAIL line to
  `state/gna-mail.log` and a Rune when the desk or the mailbox cannot be read.
- **The spine is append-only.** A re-judgment appends a new line for the same `id`;
  readers take the latest. Retention is reported, never silently truncated.
- **Rules first; no model at P0.** A message the rules cannot judge lands in
  **Unsure** with low confidence instead of being guessed at.

## Not built yet (plan 116, in order)

Drafts and approvals (P1) on the same gate · a second account with its own grant
(P2) · the agent door `mail_search · mail_thread · mail_draft` (P3) · rules that
earn their place (P4). None of them may add a send path.

## Appended 2026-10-24 — the send path she is owed goes through the gate, not around it

Plan 116 P1 (drafts and approvals) is still owed, and this line is the debt written down before anyone pays it
(today it was only a hope, which is how a hole opens): **when Gná's draft and send verbs land they must call
`bin/time/snotra/snotra-approve.sh gate mail <draft-id>` before any send, exactly as `mail-send.sh send` does.**
No SMTP, no `users/me/drafts/send`, no socket of her own — the gate is the only socket in the house (plan 124 §7).

The two wards that keep this honest are already standing: `tests/test_gna.py::NoSendCapability` fails if a send
pattern appears in any file here, and
`bin/time/snotra/tests/test_outbound_gate.py::GnaOwed` fails if a send in `bin/` does not name the gate.
