# Gná — the one mail desk

**What it is.** One page that answers *"what needs me?"* across the mailbox Ymir reads. It is not a
mail client: there is no send button, no draft box, and no way to widen it to another account. Each
message arrives judged — six classes, six proposed actions — and every row shows the rule **and the
word** that gave it. **Gná** is the messenger who carries word and brings it back; she drafts, she
never speaks for the Allfather.

**What you need.** A scoped account in the vault (the Gmail grant), and the desk service raised. The
store lives in the home (`hodd/memory/mail/`), never the repo — and the message bodies themselves are
git-ignored: schema, scope and retention travel, raw mail does not.

**The commands**

```sh
cd "$YMIR_HOME/hodd/bin/gna-agent"

python3 gna_import.py --account <the scoped account> --days 7 --dry-run   # read, write nothing
python3 gna_import.py --account <the scoped account> --days 7             # fill the store

python3 gna_desk.py            # the desk on 127.0.0.1:8490 (token: hodd/state/gna-desk.token)
python3 gna_desk.py --print-token

python3 tests/test_gna.py      # 16 proofs, including "no file here can send"
```

Then open **Hlidskjalf → Gná**. The page forwards three routes
(`/api/mail/accounts`, `/api/mail/queue`, `/api/mail/message`) to the desk with its token, and the
desk's refusals come back unchanged.

**The four columns**

| Column | What it means | What you do |
|---|---|---|
| **Needs you** | judged with confidence, an action proposed, nothing sent | approve · change · dismiss |
| **Unsure** | low confidence, or a sender the book does not know | assign · teach · dismiss |
| **Waiting** | outbound, no answer yet | nudge · close |
| **Done** | a notice recorded, or bulk mail that asked nobody anything | read only |

**The limits — read these as promises**

- **Machine sends: zero.** No SMTP, no draft creation, no Gmail send endpoint exists in the desk, and
  a test fails if one appears.
- **An account is the boundary.** A query without an account is refused (HTTP 400), and so is a
  message fetched through another account's scope. The UI hiding things is not a boundary; the store
  refusing is.
- **Rules only at this phase.** No model sees a mailbox. A message the rules cannot judge lands in
  **Unsure** with low confidence instead of being guessed at.
- **Read-only in the gate.** Drafts and approvals (plan 116 · P1) are not built yet; the page cannot
  send, and neither can the service behind it.

**If it does not work**

| Symptom | What it means | The mend |
|---|---|---|
| The page says *"the desk has no token yet"* | the desk has never run | `python3 gna_desk.py` in `hodd/bin/gna-agent` |
| *"the desk did not answer at 127.0.0.1:8490"* | the service is down | raise it, or check `ss -tln \| grep 8490` |
| *"account scope required"* | no account was chosen | pick one at the top; one must be declared in `hodd/memory/mail/accounts.yaml` |
| *"account not declared in …"* | that address has no grant row | add the row **with its own grant** — never widen another account's |
| Everything reads as **Unsure** | the sender is not in `collaborators.yaml` | add the person (or teach a rule in P4) — a stranger is meant to wait |
| A bulk newsletter wants your judgement | its `List-Unsubscribe` / `Precedence` header is missing | that is the rule's evidence; the row says which marker it looked for |

**Measured 2026-10-23.** Seven days of the operator's own mailbox: 61 messages → **needs you 5 · unsure 1 ·
waiting 20 · done 35**, machine sends 0. The first run judged a forwarded meeting recap as an
*invoice* and put 35 newsletters in Unsure; the fix was evidence that names the word, and a bulk rule.
