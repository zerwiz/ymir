## skills · unversioned · 2026-10-20 — the operator signs, and Ymir is named

### What

The follow-up signature was a document edit. It is now a system record:

`$YMIR_HOME/hodd/identity/operator.yaml` — name, email, organization, partners,
signature style, and whether AI assistance is disclosed:

```yaml
name: the operator
email: operator@example.com
organization: the company
partners: [a participant, a participant, a participant]
signature:
  style: team                 # team | minimal
  disclose_assistants: true
  assistants:
    - name: Snotra
      system: Ymir
      note: "Prepared with Snotra, Ymir's meeting assistant. Reviewed by the operator."
```

The pipeline reads it and fills `meeting.sender`, `sender_email`, `sender_org`,
`partners_line` and `signature_note`; no meeting document hardcodes a name.

Rendered signature (team style):

```
Kind regards,

the operator
the company
operator@example.com

Partners: a participant, a participant, a participant

Prepared with Snotra, Ymir's meeting assistant. Reviewed by the operator.
```

### Verified

- Removed `sender` from the pilot review; the pipeline filled it from the identity.
- Regenerated: 6 decisions, 16 actions, 0 warnings; the signature rendered as above.
- Partners are recorded as partners; Snotra is named as Ymir's assistant; the human
  review is stated.

### Not verified

- No unit assertion yet for the signature block; add one to the render suite.
- No mail transport is wired: the email is rendered, not sent.

### Appended 2026-10-20 — the dependency map

The renderer now writes `dependency-map.md`: a Mermaid `graph TD` grouped by owner,
one node per action with its due date, and an edge for every `dependency` naming
another action. The pilot renders 16 actions across four owners — what waits on what,
in one view.
