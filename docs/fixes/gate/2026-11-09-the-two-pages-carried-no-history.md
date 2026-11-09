# Two new pages carried no history

**Date:** 2026-11-09 · **Component:** gate · **Door:** `bin/gates/guards/rules-compliance-guard.sh` (R1)

## What was wrong

PR #610 added two feature pages, `docs/features/rodd-the-hands.md` and
`docs/features/the-context-budget.md`, and neither ended with a `## CHANGE LOG` section. R1 of the
rules-compliance ward refuses exactly that — a new document must carry its own history in the
document, not only in the fix note beside it — so CI's `The gates` failed on the branch while
`origin/main` was green for that ward. That made it the branch's fault, not main's.

```
rules-compliance[1]{file,line,rule,finding}:
  "docs/features/rodd-the-hands.md","-","RULES/06 · append-only","a new document has no CHANGE LOG section"
  "docs/features/the-context-budget.md","-","RULES/06 · append-only","a new document has no CHANGE LOG section"
```

## What was forged

A `## CHANGE LOG` section with the dated line that opened each page.

## Verified

```
$ bin/gates/guards/rules-compliance-guard.sh
rules-compliance[2]{state,added,range}:
  "clean",13,"origin/main..HEAD"
```
