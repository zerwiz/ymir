# Done means it has run live

**Date:** 2026-11-28 · **Component:** gate (RULES/08)

## Why

On 2026-11-27 several features that had passed their tests and merged were found not working in the house: the
heart's arm did not survive a restart, a worker liveness watch armed nothing on one road, reports claimed pushes that
never happened, and every machine judged PRs. Each had been called done after tests with stand-ins.

## The change

RULES/08 gains an appended section: a change is **merged**, then **released**, then **done** only after it has run
live on the machine whose role it serves for a day, with the proof appended to its fix note or feature page. Reports,
PR bodies, plans and wakes name the stage reached.

## CHANGE LOG

- 2026-11-27 — review-mend: added missing heading for #977
