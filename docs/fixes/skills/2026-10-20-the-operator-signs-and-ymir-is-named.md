## skills · unversioned · 2026-10-20 — the operator signs, and Ymir is named

### What

The follow-up signature was a document edit. It is now a system record:

`$YMIR_HOME/hodd/identity/operator.yaml` — name, email, organization, partners,
signature style, and whether AI assistance is disclosed:

```yaml
name: Lars-Josef Lindbom
email: josef@way-of.com
organization: Synteon Technologies
partners: [Reygan Assareh, Isabella Jakobsson, Craig Martin]
signature:
  style: team                 # team | minimal
  disclose_assistants: true
  assistants:
    - name: Snotra
      system: Ymir
      note: "Prepared with Snotra, Ymir's meeting assistant. Reviewed by Lars-Josef Lindbom."
```

The pipeline reads it and fills `meeting.sender`, `sender_email`, `sender_org`,
`partners_line` and `signature_note`; no meeting document hardcodes a name.

Rendered signature (team style):

```
Kind regards,

Lars-Josef Lindbom
Synteon Technologies
josef@way-of.com

Partners: Reygan Assareh, Isabella Jakobsson, Craig Martin

Prepared with Snotra, Ymir's meeting assistant. Reviewed by Lars-Josef Lindbom.
```

### Verified

- Removed `sender` from the pilot review; the pipeline filled it from the identity.
- Regenerated: 6 decisions, 16 actions, 0 warnings; the signature rendered as above.
- Partners are recorded as partners; Snotra is named as Ymir's assistant; the human
  review is stated.

### Not verified

- No unit assertion yet for the signature block; add one to the render suite.
- No mail transport is wired: the email is rendered, not sent.
