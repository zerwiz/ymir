# The MCP read the meeting record and knew no board at all

**Date:** 2026-11-07 · **Component:** gimle · **Status:** fixed — the board is now the MCP's truth, proved on the
real board

## The fault

The Allfather asked whether the MCP could carry his plans onto the board, and then asked it directly. The served
server answered, on 2026-11-07:

```
who_am_i        → places: two MEETING IDS
list_places     → the same two meetings, 0 open each
my_tasks        → count 0
who_owes_what   → count 0
place_board ymir/projects → "no such place in the record"
```

Its unit starts with `--data …/meetings.json`. **The MCP has never read Plane.** Meanwhile the desk on the same
box, with the same token directory, rendered `9 card(s) assigned` through `plane_reader.py` — so the board, the
token and the reader were all fine, and only one face of the hall had never been wired to them.

It is worse than an unfilled gap, and this is the part that had to be named: **six tokens seat five
collaborators** with real place columns (`Example4`, `Growth`, `InvestReady`, `WayOf`, `Example8`, `Michael`), and
every one of them would have counted zero with nothing saying why. A door that refuses everything for the wrong
reason cannot be told from a door that works.

## What was wrong in the mechanism, not only the wiring

1. **A place was a meeting.** The tools looked for a place among meeting titles. Nothing could resolve a project.
2. **Scope was a string prefix.** `may()` asked `place.startswith(token_place)`, so with places named
   `<workspace>/<project>` a token saying `Ymir` no longer matched its own project. Scope is now the resolved
   project **id**, compared by identity.
3. **`my_tasks` ignored scope entirely.** It used `board_for()`, which reads every workspace for the desk where
   the person *is* the scope. Handed an Example4-only token, it returned a Ymir card. Cards are now filtered to
   the places on the token.
4. **Two tokens for one subject silently revoked the first.** The token file was read into a dict keyed by
   subject, so the last line won. Found by this change's own self-test, which is why the self-test exists.
5. **A member was matched by a name nobody has.** The board identifies a person by email; the caller arrives as a
   subject. Both are now accepted.
6. **A backend error killed the request** — an empty body, no audit line. The tool answers `isError` with the
   reason instead, and a failed comment no longer undoes a state move that already landed.
7. **The audit said "refused" and nothing else.** A read-only door and a missing place are different faults; the
   recorded reason now carries the tool's own words.

## What landed

- `plane_reader.py` gains the readers the MCP needed — `projects`, `states`, `issues`, `members`, one cached
  read each (`CACHE_SECONDS`, shared with the desk) — and `write()`, the single place in that file that sends a
  body, so a write can be found by grepping one word.
- `mcp-read.py` gains `--plane`, `--workspaces`, `--docs`, `--allow-write` and a `Board` backend: a place is a
  project, `who_am_i`/`list_places`/`place_board`/`my_tasks`/`who_owes_what` answer from the board, and
  `meeting_record` keeps the meeting record untouched.
- Three tools: `create_card`, `update_card` (both refused unless the unit carries `--allow-write`) and
  `list_plans` (the mirrored documents the hall already serves — never a second copy of a plan).
- `bin/gates/tests/test_gimle_mcp_board.sh` — ten claims, proved by command against a stub that serves exactly
  the four endpoints the reader uses, with invented project names only (RULES/04: a client name is not a
  fixture).

## Measured

Proved on the **real** board on the heart, from a scratch copy on a spare port, the live service untouched:

```
subject A · who_am_i    → allowed_places: wayof/WayOf · example-8/Example5 · example-4/Example4 · wayof/Example9 · wayof/InvestReady
subject A · list_places → open: 7 · 0 · 24 · 25 · 9      (65 real cards)
subject B · place_board → 24 cards, its own state names (Todo …), real titles
create_card on a read-only unit → refused, and the audit line carries the reason
```

Before this change the same calls answered `count 0` and `"no such place in the record"`.

```
self-test[1]{script,cases,verdict}:
  "bin/gates/tests/test_gimle_mcp_board.sh","10","PASS"
```

## What it still does not do

The server binds `127.0.0.1:8489` on the heart and is **not published on a hostname**, so a collaborator on
another machine cannot reach it — `mcp.gimle.zerwiz.org` answers `000`. That is plan 217's G0, and it waits on
the Allfather's word because it is the moment the door becomes reachable from outside the house.

## Files

- `bin/gimle/plane_reader.py` — the readers and the one write door.
- `bin/gimle/mcp-read.py` — the board backend, three tools, the scope and audit corrections.
- `bin/gates/tests/test_gimle_mcp_board.sh` — the proof.
- `docs/features/gimle-the-hall.md` · `docs/features/_catalogue/entries/00-001-team-giml-…md` — the page and its row.

## CHANGE LOG

- **2026-11-07** — the fault measured (the served MCP answered `count 0` and `"no such place in the record"` while
  the desk read nine assigned cards); the six mechanism faults named and fixed; `--plane` and the `Board` backend
  added; `create_card`, `update_card`, `list_plans` built; ten-case self-test added; proved on the real board from
  a scratch copy on a spare port. Nothing deployed — the live unit keeps its read-only face until the operator's
  word.
