# 58 — Atlas is not Ymir

**Added 2026-11-18** at the Allfather's word: *"in atlas there should be no ymir. in ymir there should be no atlas."* and, of the atlas map, its tool and its pages: *"all those things are atlas. not ymirs."*

## The law

Atlas and Ymir are two projects, and neither carries the other.

- Ymir's tree holds no Atlas material: no tool, page, register row, path or word. The atlas map (`bin/records/atlas.sh`, `hodd/ATLAS.md`) was Atlas's and has moved out.
- A thing that is Atlas's is **moved** out whole, never deleted (RULES/11). The four files moved on 2026-11-18 sit in the home under `hodd/reference/atlas-moved-from-ymir/`.
- The ward is `bin/gates/guards/rules-compliance-guard.sh` (R5). It refuses the whole word "atlas" on any line a push adds to a Ymir file. It matches the whole word only, so "Atlassian" (Jira) is not a hit.
- Law and history that must name the word are exempt: `docs/fixes/*` (a note records what it fixed), `RULES/*` (a rule names what it forbids), and the guards and their tests (a ward searches for it).

## What this does not cover

The other half, no Ymir inside Atlas, is for the Atlas project's own gate. Ymir does not edit that repository.

## CHANGE LOG

- **2026-11-18** — opened.
