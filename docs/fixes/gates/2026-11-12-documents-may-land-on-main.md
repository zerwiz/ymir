# Documents may land on main

**Date:** 2026-11-12 · **Component:** gates · **Door:** `bin/gates/guards/branch-guard.sh --documents` · `bin/gates/guards/fixes-guard.sh`

## What was wrong

Every change, even a one-line document fix, had to go branch, PR and a merge by the Allfather's hand.
`branch-guard.sh` refused any push that landed on `main`, whatever it carried. His word: *"documents should
be able to push on main."*

## What changed

`branch-guard.sh` now lets a push land on a protected branch when every file in the range is a document by
the exact set in RULES/08, and the push is a fast-forward:

- `docs/**/*.md`, added or modified, except `docs/features/_catalogue/**`;
- `docs/fixes/<component>/*.md`, added only;
- `RULES/*.md`, added, or modified with zero deleted lines.

A deletion, a rename, a non-Markdown file, a creation or deletion of `main`, or any other path is refused,
and the refusal names the first file that broke the set. `branch-guard.sh --documents <base> <head>` asks
the question by hand.

`fixes-guard.sh` owes no fix note for a document-only range, unless a `RULES/` file changed. A rule change
keeps its record.

## Proof

`.agents/tests/branch-guard-documents.test.sh` (21 cases) passes, and the old
`branch-guard-delivery.test.sh` and `fixes-guard-deletion.test.sh` still pass.

## CHANGE LOG

- 2026-11-12 — written with the change it describes.
