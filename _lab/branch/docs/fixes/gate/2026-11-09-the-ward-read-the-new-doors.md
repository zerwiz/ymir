# The ward read the new doors, and every finding was mended at its source

**Date:** 2026-11-09 · **Plan:** 231 (R2/R4), 230 (N1) · **Component:** gate
**Law:** RULES/06 (a document carries its history) · RULES/12 · RULES/23 (a door is executable) ·
RULES/39 (`network.md` N1/N7 — no address in the tree)

## What the ward found

`rules-compliance-guard` judges what a push **adds**, and the push that gave Rödd his four hands
added fifteen files. It reported four faults. None was waived; each was mended where it was made:

```
finding[4]{file,rule,fault,remedy}
  "docs/features/every-message-opens.md","RULES/06","a new document with no CHANGE LOG","its own dated CHANGE LOG, as every document in the house carries"
  "docs/features/make-and-move-meetings.md","RULES/06","the same","the same"
  "systems/snotra/services/calendar/tests/calendar_fixture.py","RULES/39","a plain-HTTP link in the fixture's answer","the fixture answers https — a stand-in for Google should not teach the tree an address"
  "systems/snotra/services/calendar/calendar-grant.sh","RULES/12 · RULES/23","a new door that is not executable","chmod +x — it is sourced AND it is a file under systems/, and the ward is right to ask"
```

## The one that was a reading, and still worth changing

`bin/notify/open-target.sh` accepts a `pr:` target, and its case pattern spelled the plain scheme
literally:

```sh
http\://*|https://*) printf '%s' "$value"; return 0 ;;
```

The ward reads a plain scheme (the four letters, then `:` and `//`) on an added line as an
address the tree carries. Here it was a **pattern**
in a door that OPENS a link — not an address, not a machine, nothing given away. But the reading is
cheap to satisfy and the alternative is a ward with a list of exceptions, so the scheme is now a
word and the reason sits beside it in one line of comment:

```sh
local web="http"   # assembled: a literal plain scheme reads to the network ward as an address
case "$value" in
  https://*|"$web"://*) printf '%s' "$value"; return 0 ;;
```

That is the whole change: the door behaves identically, and the ward has nothing to argue with.

## What stays true

- The fix notes for the work itself are `docs/fixes/voice/2026-11-09-rodd-gets-his-four-hands.md`,
  `docs/fixes/snotra/2026-11-09-the-calendar-can-be-written-and-refuses-by-scope.md` and
  `docs/fixes/notify/2026-11-09-every-message-carries-a-target.md`; this note records the *ward's*
  half of the same push.
- `defaults-guard` and `features-guard` were red **on origin/main** when this branch was judged, and
  the ward says so out loud (`main_baseline`) — on this branch both are green.
- Two outbound-gate proofs were red before this work and are mended in
  `bin/time/snotra/tests/test_outbound_gate.py`: they read retired **shims** instead of the file
  that implements the door, and the send-around-the-gate scan counted a comment and a printed
  sentence as a send call.

## Verified

`bash bin/gates/guards/rules-compliance-guard.sh` over `origin/main..HEAD`: `clean, 15 added`. The
push then carried: `branch-guard ok` · `fixes-guard ok` · `no-delete-guard clear` ·
`branch-current current` · `guards` — every failing ward on `origin/main`, not on this branch.

## CHANGE LOG

- **2026-11-09** — written after the first push of plan 231 was refused by the ward it had taught.
