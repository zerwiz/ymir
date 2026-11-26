# Hermes gets the turn-end event

## What went wrong

The Hermes seat had hooks for the start of a session only.

## What changed

`arm.sh hook hermes --install` seats and consents `post_llm_call`, and adds it to an older seat under the existing `hooks:` key, keeping a backup.

## Proof

Installed against a temporary Hermes config; `--check` passed.

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #966
