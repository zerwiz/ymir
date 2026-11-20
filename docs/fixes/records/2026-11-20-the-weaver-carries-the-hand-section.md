# records · unversioned · 2026-11-20 — the weaver carries the hand's change log

A record a person wrote by hand was erased by the next commit, whichever commit that was.
`.agents/backend/README.md` is rebuilt by `bin/gates/inventory.sh`, and the pre-commit hook re-weaves
every woven file and stages it — so the `## CHANGE LOG` a hand appended (2026-11-18, #825;
2026-11-19, #831) survived exactly until the next commit and then vanished. That is an append-only
record lost (RULES/06), and it was lost by a generator that only knew how to overwrite.

## The proof that it was real, not a worry

It happened on this errand, before anything about weaving was touched:

```text
$ git show --stat 30a65576 | head
 .agents/backend/README.md    |  4 --
 bin/forge/pr-patterns.sh     | 21 +++++----
 …

$ git show 30a65576 -- .agents/backend/README.md | tail -6
-
-## CHANGE LOG
-
-- 2026-11-19 — review-mend: added missing heading for #835
```

Commit `30a65576` was a *gates* fix about mailboxes. It deleted a mail-desk record because the
hook wove the page it lived on.

The history shows the same loss five times over — each entry is the last one standing before the
next commit:

```text
d0d93efd  - 2026-11-18 — review-mend: added missing heading for #825
9cb766c5  - 2026-11-19 — review-mend: added missing heading for #832
79f430da  - 2026-11-19 — review-mend: added missing heading for #833
0ee9c408  - 2026-11-19 — review-mend: added missing heading for #835
```

## What changed

One door owns the rule, so a second weaver cannot get it a second way:
`bin/records/woven_tail.py`.

- A woven page is written as the generated body, a sentinel line, and then the hand section
  **byte for byte**.
- A page **already carrying the sentinel** (written by this door) hands over everything after the
  last sentinel — even tables and row-shaped lines, which a generated page also holds.
- A **legacy** page, written before the sentinel existed, is read by the older test: the last
  `## CHANGE LOG` heading is the hand's only when what follows it is prose. A register whose
  *generated* header carries a change-log paragraph of its own, with rows underneath
  (`bin/README.md`), is therefore not mistaken for a hand.
- `bin/gates/inventory.sh` composes through it for every page it builds.
- `bin/records/weave-features.sh` composes through it too (and its `--check` compares the composed
  page, so the sentinel never reads as drift).
- A seat with an older pin, or a tree where the helper is missing, still writes the body: a
  register that cannot render is worse than a hand section that does not travel.

## The section is restored

The erased entries are recovered from git history and the section is back, carried by the weaver:

```text
$ bash bin/gates/inventory.sh >/dev/null && sed -n '/woven:hand/,$p' .agents/backend/README.md
<!-- woven:hand · everything below is carried through unchanged by the weaver (RULES/06) -->

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #821
- 2026-11-18 — review-mend: added missing heading for #825
- 2026-11-19 — review-mend: added missing heading for #832
- 2026-11-19 — review-mend: added missing heading for #833
- 2026-11-19 — review-mend: added missing heading for #835
- 2026-11-20 — the section is restored, and the weaver now carries it through unchanged
```

Two weaves in a row leave the page byte-identical, which is the property the hook depends on:

```text
$ cp .agents/backend/README.md /tmp/b1 && bash bin/gates/inventory.sh >/dev/null && cmp /tmp/b1 .agents/backend/README.md
STABLE: two weaves, byte-identical
```

## Proof

```text
$ bash bin/gates/tests/test_woven_hand_tail.sh
a page with nothing appended is the generated body
  ok   no hand section: the body is written as it is
a legacy hand section (written before the sentinel existed) is carried
  ok   the sentinel marks where the hand section begins
  ok   the first hand entry survives
  ok   the second hand entry survives
  ok   a second weave changes nothing (the tail is stable)
a sentinel already written carries ANY hand content, tables included
  ok   a table in the hand section survives
  ok   a row-shaped hand line survives (the sentinel wins)
a register whose GENERATED header owns a CHANGE LOG is not the hand
  ok   a generated change-log header is not carried
the door writes the file, and a later weave keeps the hand
  ok   the entry survives two writes, byte for byte
all cases hold
```

And the feature catalogue, woven through the same door:

```text
$ YMIR_WEAVE_OUT=/tmp/out.md bash bin/records/weave-features.sh
$ YMIR_WEAVE_OUT=/tmp/out.md bash bin/records/weave-features.sh --check
FEATURES.md is built, not versioned — the fragments weave (280 entries)
```

## Files

- `bin/records/woven_tail.py` — the rule, once: `hand_section` · `compose` · `tail|write|compose`
- `bin/gates/inventory.sh` — composes through the door instead of overwriting the page
- `bin/records/weave-features.sh` — the same, and `--check` compares the composed page
- `bin/gates/tests/test_woven_hand_tail.sh` — every case, by command
- `.agents/backend/README.md` — the `## CHANGE LOG` restored from history, carried from now on
