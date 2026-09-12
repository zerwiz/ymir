---
name: saga
description: >-
  Sága — the seeress, the session's bearings. Load when the Allfather asks for
  bearings, a morning brief, status, catch-up, "where did I leave off", "what's
  in the works" (/bearings), or invokes /ahoy to recap visible events and be
  walked through unresolved decisions. Covers the fleet digest, the dated status
  artifact, the interactive fleet board, and the recap.
user-invocable: true
metadata:
  internal: true
---

# saga — bearings — fleet status digest (/bearings) + recap (/ahoy)

Sága sees and tells. This skill is how Brokk reports where things stand and
closes unanswered calls.

```
assets[3]{path,load_when}:
  "assets/bearings.md","/bearings — fleet status digest / pick-up-where-I-left-off; file + lavish modes"
  "assets/recap.md","/ahoy — recap visible session events + unresolved Allfather decisions"
  "assets/board-template.html","the interactive fleet board template armed by /bearings lavish"
```

A change to how Brokk reports bearings edits an asset here, not a new skill.
