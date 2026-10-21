# 26 — The external surface: private data does not leave the house

**Appended 2026-10-20** at the Allfather's word — *"we should not mention my file path in
the things"*, and then *"append to the system: never leak private data or private specific
information; we need some kinds of guards for this system."*

**Why it exists.** A meeting card, an email and a public PR are **outside** the vault. They
are read by other people, stored by another company, and may be indexed or forwarded. A
local path in a Trello card is not a convenience — it is a map of the private house handed
to a third party. The same is true of a vault filename, an internal note title, a token, a
machine name used as an address, or a private plan.

The meeting chain crosses that boundary every day: the record is written in the hoard,
then rendered into a PDF, mailed, and projected onto Trello. The guard is therefore part of
the chain, not an afterthought.

```
external_surface_law[8]{rule,what it means}:
  "THE VAULT IS INSIDE","a local path, a hoard filename, a private note title or a vault reference never appears in a Trello card, an email, a Chat message or a public PR."
  "SECRETS NEVER CROSS","no key, token, password, connection string or private URL is written to an external surface, not even in an example."
  "NAMES ARE NOT ADDRESSES","a person may be named as a participant; their private address book, private notes and machine paths are not part of the meeting record."
  "THE RECORD IS THE MINIMUM","an external artifact carries what the meeting decided and who does what — not the file structure that produced it."
  "CHECK BEFORE THE DOOR","every send or export runs `bin/gates/guards/private-guard.sh`; a finding stops the operation, it does not warn and continue."
  "REDACT THE EVIDENCE","a guard reports the file, the line and the kind of finding — never the secret value itself."
  "THE GUARD IS NOT A MOOD","the check is wired into `mail-send.sh` and `snotra-trello.sh`, so the safe path is the only path."
  "A CORRECTION IS APPENDED","if private material reached an external surface, remove it there, record the incident in the runes, and append the correction here; never rewrite the history."
```

## What the guard refuses

- absolute paths: `/home/...`, `/Users/...`, `C:\...`
- home and vault references: `$YMIR_HOME`, `~/Documents/ymirhome`, `hodd/...`,
  `svartalfaheim/...`, `.yggdrasil/...`
- private filenames and vault files: `platform.env`, `age.key`, `secrets/`, `*.age`
- secret shapes: `sk-…`, `ghp_…`, `AKIA…`, `BEGIN … PRIVATE KEY`, `password=`,
  `api_key=`, `Bearer …`
- machine-private addresses used as service URLs (a LAN IP or `.local` name in a path
  where a public endpoint is required)

It does **not** refuse a participant's name or email: those are the meeting's own actors,
and the record must say who decided and who owns the action.

## The tool

```sh
bin/gates/guards/private-guard.sh check FILE...
echo "a line" | bin/gates/guards/private-guard.sh check --stdin
bin/gates/guards/private-guard.sh scan-meeting "$YMIR_HOME/svartalfaheim/<realm>/meetings/<id>"
```

Exit `0` clean, `1` finding. Every finding is printed as
`file:line: kind` with the value redacted.

## Where it is wired

- `bin/time/snotra/mail-send.sh` — the body and HTML, and every text-like attachment,
  before the MIME is built.
- `bin/time/snotra/snotra-trello.py` — every card name, description and checklist item,
  before the API call.
- `bin/time/snotra/snotra-render-email.sh` / `snotra-render-pdf.sh` — the rendered letter
  and record are checked by the send/export path that carries them.

Law 26 sits beside Rule 04 (the hoard) and Rule 15 (vault confidentiality): Rule 04 says
where private data lives; Rule 15 says vault content never leaves; Rule 26 says the
**meeting chain** must not carry private structure onto a third-party surface.

---

## Protected material — the NDA register (appended 2026-10-20)

The company's NDA is not a normal document. It defines **Confidential Information** to
include concepts, architecture, algorithms, source code, business strategy, funding and
patent strategy, partner identities, and **all notes, summaries and derivatives** of them.
It permits disclosure only to professional advisers bound by confidentiality and to persons
approved in writing who have signed an undertaking on the same terms. It requires dated
records of disclosures, forbids copying material to accounts, devices or repositories not
used for the Purpose, and permits AI tools only where inputs and outputs are excluded from
model training.

The protected set is therefore kept in a private register,
`hodd/identity/confidential.yaml`, with the SHA-256 of each protected document, the four
authorised party addresses, the markers, and the surface policy:

```
surfaces:
  private: allow
  email:   parties-only
  trello:  deny
  public:  deny
```

The guard reads that register. A protected document — by hash, or by a marker such as
`COHERANS`, `Mutual Non-Disclosure`, `Annex A-1`, `Annex B-1`, `Background IP`, `WO-IP-`
or `Confidential Information` — is refused on Trello and on any public surface, and on
email unless **every** recipient is one of the four parties. A derived record that carries
those markers inherits the rule: the NDA says derivatives are confidential too.

**What this means in practice**

- The NDA and its annexes are **never** attached to a Trello card, a Chat message or a
  public PR.
- They may be emailed only to the four parties, and only while the AI-tool condition is
  met for whatever tool processes them.
- A meeting record that discusses the NDA may be emailed to the parties; its decisions do
  not belong on a board shared beyond them. If the board is ever opened to an adviser, the
  register must be extended first, by the rights holder's written approval.
- A finding stops the operation. The guard reports the file, the line and the kind —
  never the protected value.

This section is a guard, not legal advice. The NDA's own clauses govern; where they are
stricter than the guard, the NDA wins.

## 2026-10-21 — and the public tree is not a meeting record (appended)

The clarification this rule needed, from the incident above: **Rule 26's permission to name a
participant applies to a meeting record, an email to the parties, or a board shared with them — it does
NOT apply to this repository.** The public tree is the widest external surface there is: a name there is
indexed, mirrored and copied, and no correction can follow it.

So `private-guard`'s silence on a name was correct and insufficient. `people-guard` covers the tree:
**a person from the operator's registries never appears in it — a role does.**
