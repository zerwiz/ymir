# Fix: CI fetches the base on push too

Date: 2026-11-09
Component: gates

Workflow now fetches origin/main (or the PR base) for push events as well, so
nodelete_base resolves a base on both events and the no-delete gate runs the same
range on one sha.

## CHANGE LOG

- **2026-11-09** — written with the fix: the base is fetched on a push as well as on a pull request, so one
  sha has one verdict. (The section was added after the judge refused the note for the very rule it obeys —
  RULES/06 — which is the guard catching its own author, and correct to do so.)
