# Collaborators — the people you work with, in one place

**What it is.** A registry of clients, collaborators, advisers and partners, kept in the vault, with
one door that writes it, validates it, and — importantly — is the only sanctioned way to email one
of them.

**What you need.** The vault (`$YMIR_HOME`). The registry is
`$YMIR_HOME/hodd/identity/collaborators.yaml`; copy `config/collaborators.yaml.example` to start.

**The commands**

```sh
bin/people/collaborators.sh list [--kind client|collaborator|adviser|partner|prospect]
bin/people/collaborators.sh show <id>
bin/people/collaborators.sh add <id> --name "…" --kind collaborator --org "…" --email a@b.c --project …
bin/people/collaborators.sh set <id> status active
bin/people/collaborators.sh check
bin/people/collaborators.sh email <id> --subject "…" --body FILE [--dry-run]
```

**Why the door and not a text editor.** A person record is easy to get subtly wrong, and the
mistakes are social, not technical:

- `check` validates every record — unique ids, a real name, one of the allowed kinds and statuses, an
  address that looks like an address — and, when a record claims `nda: true`, that the address is
  actually in the NDA register. A claim of confidentiality that is not on file is a finding.
- `email` refuses a `former` contact, refuses a person whose `consent.email` is false, refuses a
  person with no address, and **runs the private/NDA guard (Rule 26) over the body before the mail
  door is called**. A finding stops the send rather than warning and continuing.

**Limits.** It does not store message history — the mail door keeps the drafts, and the Runes ledger
keeps the fact that something was sent. It does not verify that an address is the right person's;
that is a human judgement, and the notes field is where you write down what you were told.

**If it does not work.** `check` first: it names the record and the field. If `email` refuses, the
message says which gate refused — a guard, a consent flag, or a missing address.
