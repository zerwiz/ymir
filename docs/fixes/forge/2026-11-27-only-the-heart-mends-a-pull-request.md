# Only the heart mends a pull request

**Date:** 2026-11-27

## What was wrong

`review-mend.sh` committed and pushed from any seat onto any open pull request. Mend commits from another seat kept
landing on branches while their authors worked on them, and published that seat's commit address.

## The fix

The door refuses on every seat but the heart (exit 4, and it says what to do instead), skips a pull request opened by
someone else unless asked with `--mend-others`, and skips when the commit address is not a no-reply one. The law is in
RULES/08.

## What it does not do

A seat still on an older tree keeps the old behaviour until it updates.

## CHANGE LOG

- 2026-11-27 — written with the fix.
