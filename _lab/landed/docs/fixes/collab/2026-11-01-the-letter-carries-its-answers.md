# 2026-11-01 — the letter now carries its own answers

**Component:** collab (Vingólf) · **Door:** `bin/collab/letter.sh` · **Letter:** `letters/collaboration-files.md`

## Why

The Allfather asked for the letter to contain what it needs. The first draft asked the question and left the
reader to work out what it meant in practice — a proposal that reads as a new tool is a proposal that gets a
polite "let us discuss".

## What changed

1. **"What it is not"** — a paragraph that says plainly: no new tool, no migration, Trello stays Trello and the
   team suite stays as it is, nobody signs in anywhere new. This is the paragraph the question needed.
2. **"How to answer"** — three one-line replies (*yes, all projects* · *yes, but only these* · *no, and here is
   what we would prefer*), so a busy counterpart can answer in a sentence rather than write one.
3. **The attachments are named in the letter** — the one-page law and the page to fill in, so the reader sees the
   shape before answering.
4. **The walk-through offer** — ten minutes, if they would rather see it than read it.
5. `letter.sh` strips the leading blank line left by removing the `Subject:` header, so the rendered body starts
   with the greeting.

## Measured

A draft was created with both files attached and **not sent** — sending is the Allfather's word, and the door has
no send path. The rendered letter, the recipient and the draft id live in the private home
(`hodd/state/collab/letters/`), never here: this repository is public, and a counterpart's address is not ours to
publish.
