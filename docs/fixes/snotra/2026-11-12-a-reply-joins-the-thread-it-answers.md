# snotra · 2026-11-12 — a reply joins the thread it answers

## Files
- `systems/snotra/services/letters/mail-send.sh`: `draft --reply-to <gmail-message-id>` sets `In-Reply-To`, `References` and the draft's `threadId`; `--subject` defaults to `Re: <their subject>`
- `bin/time/snotra/tests/test_outbound_gate.py`: the stand-in Gmail serves a message and records each draft's thread; two new mail tests
- `docs/features/letter-templates.md`, `.agents/skills/snotra-letters/SKILL.md`: how to answer a thread

## Why
The door could only start a conversation. A reply drafted with it carried no `In-Reply-To` or `References` header
and no `threadId`, so Gmail and every other client filed it as a new thread. The recipients saw the answer apart
from the message it answered.

On 2026-11-12 an operator's reply to a partner thread had to be placed by hand: the draft was built with the
door's own `--dry-run`, so both guards still ran, and the headers and thread id were then added outside the door.
That is the kind of side road this door exists to close.

## Fix
`--reply-to <gmail-message-id>` reads that message's metadata (`Message-ID`, `References`, `Subject`, `threadId`).
The draft then carries:

- `In-Reply-To: <their Message-ID>`;
- `References: <their References> <their Message-ID>`;
- the `threadId` on the Gmail draft;
- a subject of `Re: <their subject>`, unless `--subject` is given or their subject already starts with `Re:`.

A message the API cannot read is refused before anything is drafted. Everything else is unchanged: the guards,
the design, the attachments, and the approval gate on `send`, which still binds the operator's word to the
draft's exact bytes.

## Verified
- `bash systems/snotra/services/letters/mail-send.sh --self-test`: 8/8 pass, including
  `test_7_a_reply_joins_the_thread_it_answers` and
  `test_8_a_reply_keeps_an_explicit_subject_and_refuses_an_unknown_message`.
- `python3 bin/time/snotra/tests/test_outbound_gate.py`: 16/16 pass, covering the mail and calendar doors.
- `bash systems/snotra/tests/smoke.sh`: the same 1 pass · 1 skip · 3 fail as an untouched `main` on this seat. The
  three failures need meeting records and boards that this seat does not hold yet.

## CHANGE LOG

- **2026-11-12** — note written with the change.
