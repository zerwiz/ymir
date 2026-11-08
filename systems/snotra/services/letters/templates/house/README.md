# The house letters — the shapes we actually send

The folders beside this one hold **vendored HTML templates** (Cerberus, leemunroe, Mailgun) — the rendering layer, pinned
and licence-clean. This folder holds something different: the **shape of the writing**, in markdown, for the letters this
house sends over and over.

A shape is not boilerplate. It is the order that makes a letter work: what the reader needs first, what they must do, what
they can ignore. Fill the placeholders, delete what does not apply, and keep the order.

```
letters[4]{file,when,what_it_carries}:
  "collaborator-onboarding.md","a new person joins the work","what they get, what they are, what they are not, and the one first step"
  "lesson-share.md","a lesson or a course goes to a developer","the artefact, the honesty note, and the request for corrections"
  "setup-walkthrough.md","someone is installing their own Ymir","prerequisites, the plan before the install, the checkpoints, and the failure bundle"
  "follow-up.md","a letter needs a reply and the thread went quiet","the ask restated in one line, the deadline, and the smallest next step"
```

## Rules that outlive the shapes

1. **Address the person, not the project.** A letter opens with what it is about for *them*.
2. **One ask per letter.** If there are two, they are two letters — or the second will be ignored.
3. **Never a private path, never an address.** The door refuses it (`private-guard` on the email surface), and it is right:
   a letter that carries the layout of our home cannot leave it.
4. **Say what is not done.** A letter that reads as finished when it is not buys a reply you will spend a week answering.
5. **The reader's next action is named in the imperative and in one line.** "Send back what is wrong" beats "feedback is
   welcome".

## Where the record goes

The letters themselves are not kept here. `bin/mail/ledger.sh` records what left and what arrived — the direction, the
person, the subject, the moment — and that record lives in the home, never in this repo. A template is public; a
correspondence is not.

## CHANGE LOG

- **2026-11-08** — Carved with `bin/mail/ledger.sh`, the record of what left and what arrived.
