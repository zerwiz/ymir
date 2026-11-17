# mail · 2026-11-17 — a reply names its message, or the door refuses

## Files

- `systems/snotra/services/letters/mail-send.sh` (1.0.3 → 1.1.0): a subject that opens `Re:` is
  read as a claim and proved against the mailbox; `--new-thread` is added; the three refusals name
  their reason.
- `bin/mail/tests/test_headers.py`: seven new proofs beside the existing header proofs, which share
  the letters-door fixture; the Gmail stand-in gains the one lookup the door now needs.
- `bin/mail/README.md` is unchanged (it documents the store, not the letters door).
- `bin/people/collaborators.sh`: the email door still called the retired `bin/time/snotra/mail-send.sh`
  shim, so it could not reach the letters door at all. One path, repointed.
- `.agents/skills/snotra-letters/SKILL.md` and `docs/features/letter-templates.md`: the entry skill
  and the operator's page both say what a `Re:` subject now does.
- `docs/features/_catalogue/entries/02-119-a-reply-names-its-message.md`: the catalogue row.

## Why

Three letters went out in one night with `Re:` subjects that began **new** threads.

The threading itself was not broken. `--reply-to` has set `In-Reply-To`, `References` and the Gmail
`threadId` since 2026-11-12. What was missing is that naming a message meant knowing a Gmail message
id — and the one name a person has for the message they are answering is **its subject**. So a letter
written `Re: The plan for the quarter` carried nothing that joined it to anything, and every mail
client correctly showed it as a new conversation that merely mentioned the old one.

The subject is not decoration. It is the only handle a hand has.

## What changed

A subject that opens with `Re:` is a claim: *this letter answers something*. The door proves it
before the letter is drafted, by asking the mailbox which messages carry that subject.

| The subject | The mailbox | What the door does |
|---|---|---|
| opens `Re:` | exactly one message matches | sets `In-Reply-To`, `References` and the `threadId`, and prints `answers <id> <subject> <sender> <date>` |
| opens `Re:` | no match | refuses: nothing in the mailbox carries that subject |
| opens `Re:` | more than one match | refuses, listing every candidate's id, subject, sender and date |
| opens `Re:` | the search itself fails | refuses — an unproven reply is not silently promoted to a new thread |
| opens `Re:` + `--new-thread` | any | no threading headers, no lookup; the deliberate way to start a conversation |
| does not open `Re:` | any | unchanged; the mailbox is never asked |

Normalisation is every leading `Re:` in any case, whitespace collapsed, and case folded, so
`re:   THE PLAN for the quarter` finds `The plan for the quarter`. The match is decided per
candidate by reading its `Subject` header, not by trusting the search's own relevance: a candidate
whose subject does not normalise to the same text is not a match.

`--reply-to <id>` still wins when given, and the door does not search at all in that case.
`--reply-to` together with `--new-thread` is refused, because one says *answer this* and the other
says *start fresh*.

## Why refuse rather than guess

A wrong `In-Reply-To` files your letter inside somebody else's conversation. That is worse than a
new thread, and far harder to see after the fact — the reader sees a reply that answers a message it
never saw. Two matches mean the subject does not name one message; the door cannot know which, so it
names the candidates and asks for `--reply-to <id>`.

The refuse path costs one search and nothing else: no draft bytes are posted, so a refused letter
cannot be approved by habit later.

## The proofs

`python3 bin/mail/tests/test_headers.py` — 19 proofs, all green. The seven new ones:

1. one match joins the thread (headers **and** the `threadId` on the wire), says which message it
   answers, and leaves the operator's own subject wording alone;
2. no match refuses with the named reason and posts no draft;
3. two matches refuse and list both candidates with their senders;
4. `--new-thread` produces no threading headers and never searches;
5. a non-`Re:` subject is untouched and the mailbox is never asked;
6. an explicit `--reply-to` wins over the inference, with no search performed;
7. `--new-thread` with `--reply-to` is refused as contradictory.

Everything runs offline: the Gmail API and the token door are a local HTTP stand-in, the recipient's
MX comes from a local DNS responder, and the addresses are in `.test`, which RFC 2606 reserves for
exactly this. No Google, no mailbox, no network.

## Found, not fixed

`bin/time/snotra/tests/test_outbound_gate.py` (the suite `mail-send.sh --self-test` runs) still
points at the retired `bin/time/snotra/mail-send.sh`, `calendar-invite.sh` and `snotra-approve.sh`
shims, so seven of its eight proofs fail with exit 127 after the shims were retired in #810. That is
a broken test harness, not a broken door: the direct proofs in `bin/mail/tests/test_headers.py` are
green. Repointing that file is its own errand.

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #812
