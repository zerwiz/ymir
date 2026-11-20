# The calendar can be written, and refuses by scope

**Date:** 2026-11-09 · **Plan:** 231 §2 (R2) · **Component:** snotra
**Law:** RULES/25 (a borrowed capability says so), RULES/07 (endpoints are configuration),
RULES/04 (secrets by reference)

## What was wrong

`calendar-ask.sh` is read-only **on purpose** and the reader has no write verb at all — so "make
and move meetings" was not a missing flag, it was a door that had never been built. The one write
path that existed (`calendar-invite.sh create|cancel`) mails attendees, which is right for an
invitation and wrong for a voice saying "move my eleven o'clock".

And the grant in the vault is **live but read-only for the calendar** — measured through the
tokeninfo door this evening: `email, documents, documents.readonly, drive.file, drive.readonly,
gmail.compose, gmail.readonly, userinfo.email, openid`. There is no `calendar.events` in it. A door
that assumed it had the scope would have discovered the truth as a 403 after a half-spent approval.

## What was built

```
calendar-grant.sh     ONE reading of the grant: the connect door's key (SNOTRA_GOOGLE_REFRESH_TOKEN,
                      default of gna_connect's DEFAULT_GATE_GRANT_KEY), the token refresh, the scope
                      MEASUREMENT through the connect door's tokeninfo endpoint, and the API call.
                      Also: `calendar_when`, which resolves "tomorrow 09:30" / "monday 10:00" /
                      "2026-11-12 14:00" / "14:00" to an RFC3339 instant on the operator's own clock.
calendar-write.sh     create | move | status (the real door: systems/snotra/services/calendar/)
bin/time/snotra/calendar-write.sh   a shim, per the paths ledger (the shelf moved in plan 129)
```

Behaviour that matters:

- **The scope is named when it is missing.** `calendar.events`
  (`https://www.googleapis.com/auth/calendar.events`) is printed with the two commands that
  re-consent, and the door exits 3 without posting anything.
- **Unmeasured is not a green.** If tokeninfo cannot answer, the write is attempted and Google's
  own `403 insufficientPermissions` becomes the same named refusal — the vendor is the last word,
  not a fallback to a local calendar.
- **There is no local calendar.** A failed write says so; nothing is written to a file that could
  be mistaken for a meeting.
- **`move` refuses ambiguity**, listing the matches by id, time and title.
- **`move` mails nobody** (`sendUpdates=none`) and says so. `create` delegates to
  `calendar-invite.sh`, so the event's body and the outbound-mail approval gate stay in ONE writer;
  a create with attendees posts the event and mails nobody until the operator's word is standing
  and fresh.

## The one shared library

`calendar-invite.sh` now sources `calendar-grant.sh` instead of carrying its own vault read, token
refresh and curl shape — one resolver, one refresh, one curl, one scope measurement in the house.
Its behaviour is unchanged (the outbound-gate proofs still pass); it gained the same scope refusal
before it builds a body, so a grant that cannot write is refused by name rather than after an
approval has been spent.

`bin/time/snotra/tests/test_outbound_gate.py` had a pre-existing red proof: its "read the door"
test read the **shim**, which is a two-line forwarder, so it asserted a literal that only the
implementing file holds. It now reads the file that implements the door (falling back to the shim
when the real one is absent), and the gate is green.

## Verified

`bash systems/snotra/services/calendar/tests/test_calendar_write.sh` — offline, against a local
fixture that stands in for Google, with no network and no fixture in the door:

```
the scope is the gate   read-only grant refused · names calendar.events · nothing posted
create, with the scope  created · posted body 09:00→09:45 Europe/Stockholm
move, by title          moved · the answer carries the OLD start · mail: none · sendUpdates=none
ambiguity is refused    two matches → exit 3, lists both, nothing patched
the vendor is last      tokeninfo down + API 403 → exit 3, names the scope
```

Against the real vault on this seat: `bin/time/snotra/calendar-write.sh status` answers
`"read-only","…","live","the grant lacks calendar.events — re-consent once"` and exits 3. The
refusal is real, not hypothetical.

## CHANGE LOG

- **2026-11-09** — The write hand, its scope refusal, the shared grant library, and the outbound
  gate's shim-reading proof (plan 231 R2).
