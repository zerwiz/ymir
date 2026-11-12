---
name: saga
description: >-
  Sága — the seeress, the session's bearings. Load when the Allfather asks for
  bearings, a morning brief, status, catch-up, "where did I leave off", "what's
  in the works" (/bearings), or invokes /ahoy to recap visible events and be
  walked through unresolved decisions, or asks to be
  briefed on THIS project ("brief me on this project", "where are we with this
  repo") — a per-project brief from the home's project registry, only when asked. Covers the fleet digest, the dated status
  artifact, the interactive fleet board, and the recap.
user-invocable: true
metadata:
  internal: true
---

# saga-bearings — bearings — fleet status digest (/bearings) + recap (/ahoy)

Sága sees and tells. This skill is how Brokk reports where things stand and
closes unanswered calls.

```
assets[4]{path,load_when}:
  "assets/bearings.md","/bearings — fleet status digest / pick-up-where-I-left-off; file + lavish modes"
  "assets/recap.md","/ahoy — recap visible session events + unresolved Allfather decisions"
  "assets/board-template.html","the interactive fleet board template armed by /bearings lavish"
  "assets/project-brief.md","brief me on this project — on request only; bin/records/project-brief.sh"
```

A change to how Brokk reports bearings edits an asset here, not a new skill.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
