# The letter — one per participant, from the record, and never sent unapproved

`services/letters/snotra-letter.sh` renders it, `services/letters/mail-send.sh` is the only socket that sends, and
`services/approve/snotra-approve.sh` is the gate in front of it.

## The shape

One letter per participant, carrying that person's own tasks and decisions, rendered from the meeting's record —
not written by hand, and not a second copy left beside the first:

```
letters/<person>.md      the letter
letters/<person>.html    the same letter, rendered
letters.json             what exists, and its state
```

The record is the only source. A name, a task or a decision that is not in the record cannot appear in a letter;
`services/letters/participants-fill.sh` fills addresses from the meeting's calendar event, and nothing else.

## The gate — the operator's word, bound to bytes

A letter does not leave because a door was called. It leaves when an **approval record whose hash matches the
draft's exact content** exists:

```bash
snotra-approve.sh approve <draft-id>    # the operator, on his own word
snotra-approve.sh check   <draft-id>    # exit 0 only if approved AND unchanged
snotra-approve.sh revoke  <draft-id>
```

Edit one character after approval and the approval no longer matches; the draft must be approved again. The
approval record lives outside git, in the state dir — an approval is an act, not a document.

This exists because of a measured fault: on 2026-10-23 a letter about how the company runs meetings reached the
partners before the Allfather had seen it. **Sending is not a verb anyone can call on a draft.**

## What a letter may never do

- leave without an approval bound to its bytes;
- name a person the record does not name;
- be re-typed by hand beside the rendered one (that copy is a stray — see `the-record.md`).
