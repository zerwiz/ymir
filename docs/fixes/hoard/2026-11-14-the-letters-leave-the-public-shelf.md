# The letters left the public shelf, and the shelf says so

**Date:** 2026-11-14 · **Component:** hoard (`midgard/`) · **Errand:** `out-of-git`
(plan 288 step 7, plan 287 P4)

## What was wrong

Three files sat on `midgard/`, the shelf whose own README defines it as **shared assets that are
public by design**: the design system, the shared libraries, example infrastructure. They were:

- the body of a letter to a named partner about the operator's own product work,
- the body of a letter to a second named partner about the same work,
- a partner-facing business launch document — product, positioning, business model, open questions.

A letter is private by nature. A public repository that ships to strangers' machines is the one
place it must never sit: the names, the commercial intent and the company's own plan all become
public the moment the file is committed, and they stay in the history even after a later removal.
Plan 287 §1 counted the trespass; plan 288 §1 draws the line — **people, companies, clients and the
operator's plans live in his home**, never in the program.

## The fix

- The three files **left the repository by a recorded move** (Rule 11, never a deletion) and live in
  the operator's home: `hodd/life/outreach/2026-11-14-the-snotra-letters/`, with a `README.md` in that
  folder naming each file, what it is and why it moved.
- **`midgard/README.md` gained a dated section** (appended, never rewritten — Rule 06) saying that
  three files left the shelf, what they were in the generic sense (*letters to partners and a partner
  launch document*), and what a user of this repository should do instead: the **shape** of a letter
  lives in the code and the design system; the **words** live in the operator's home; any example
  uses an invented name.
- **Nothing else on the shelf moved.** `design-system/`, `shared-packages/`, `infrastructure/`
  (which uses `example.org` placeholders) and `github_org_repos/` are unchanged.

## Why the public README does not name them

The point of the move is that a real person's name and a real company's business stop being
published. A dated note that spelled those names out again on the same public shelf would undo it.
The note therefore describes the files by **kind** and points at the shelf they went to; the
identifying detail lives in the home, where it belongs (RULES/04, plan 287 §3 rules 1 and 2).

## What is owed, and is not done here

The names were **already in the history** of the public repository before this change (plan 287 P6,
`history-scan`). Removing the files does not remove them from old commits or old clones. That is a
separate decision for the Allfather: whether anything must be rotated, rewritten or accepted as
history.

## How it was proved

```
git ls-files midgard/ | grep -E 'email-|snotra-business'      # → nothing
git log --oneline -1 -- midgard/README.md                     # the dated section rides the move's commit
ls "$YMIR_HOME/hodd/life/outreach/2026-11-14-the-snotra-letters/"   # the three files and their README
```

The bytes are identical to what left: they were copied before the removal, and the home's own commit
carries them.
