# agents · 2026-11-08 — Google's Gmail MCP has no send tool, and the voice kept promising one

## What

He asked, by voice, to *"send that to Sebastian on Gmail"* — and then, seeing the hesitation, *"Do it. Can
you open Google Gmail so I can see the email you're sending?"* Two faults were stacked under that request.

1. **There is no `send_mail`.** Measured against the seat's own Gmail MCP endpoint, the tool list is:
   `create_draft · list_drafts · get_draft · get_thread · get_message · search_threads · label_thread ·
   unlabel_thread · apply_sensitive_thread_label · trash_thread · untrash_thread · mark_thread_spam ·
   unmark_thread_spam · list_labels · label_message · update_message_labels · unlabel_message ·
   apply_sensitive_message_label · trash_message · untrash_message · mark_message_spam ·
   unmark_message_spam · create_label`. **Drafts and labels only.** The voice offered to call
   `send_mail`, which does not exist, and then apologised for its absence as if it were an outage.
2. **Every call is refused anyway.** `create_draft` answered:
   *"Access to this tool requires that your Google Cloud project (463322445860) is enrolled in the Google
   Workspace Developer Preview Program."* So even a draft cannot be written through that MCP today.

## The repair

- **`mail_compose` (new, the voice's 37th hand)** — writes the letter and **opens it as a prefilled Gmail
  compose in his own browser** (`mail.google.com/?view=cm&…`), and says, in the same breath, that it is
  **not sent**: sending is his hand on Send. That is the only honest road a voice has while the MCP can
  neither send nor be called.
- **both house briefs** now state the capability plainly: *Google's Gmail MCP drafts and labels but has no
  send tool, and its calls are refused until the Cloud project is enrolled — so never promise to send; use
  `mail_compose`, which opens a prefilled letter for him.*

## Verified

- `create_draft` through the adapter → refused with the enrolment message (recorded above, not paraphrased).
- `mail_compose` through the toolbox (the window's own path) → *"The letter is written and opened in
  chromium — a Gmail compose window addressed to him, 'Next steps: the road between houses',
  and the body filled in. It is NOT sent…"* — and a Chrome compose window stood open on his desktop.
- the live page over Chrome DevTools MCP: `37 tools | mail_compose: true`.
- the recipient's address came from `hodd/identity/collaborators.yaml` (Sebastian's row, the address he actually signs into the Board
  with) — the address itself stays in the home, never in this public tree — never from a guess.

## Not verified / owed

- **An actual send** — impossible through this MCP today. It needs either the Cloud project's enrolment, or
  the harness's own send road (the desk is `read_only`, `send_capability: none`), or his own hand.
- The compose URL opens with `Profile 1`; a seat with a different Chrome profile would need
  `CHROMIUM_PROFILE`-style resolution rather than a hardcoded profile name.

## CHANGE LOG

- **2026-11-08** — written. A tool that does not exist, a refusal read as an outage, and the honest hand
  that replaced both.

- **2026-11-08 (the same note, a moment later)** — the recipient's address was written into this public note
  and the public-data guard refused the push. Redacted here; the address lives in
  `hodd/identity/collaborators.yaml` in the home, which is where a private value belongs (RULES/04).
