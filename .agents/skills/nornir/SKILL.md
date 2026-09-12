---
name: nornir
description: >-
  Nornir — fate and schedule. Load before arming a long-polling process→event
  source Brokk owns, before registering a deterministic condition→action watch,
  on any `procevent <adapter> <source-id> <sequence>` check wake, and when a
  dispatch rule or default resolves to more than one quota-axi profile candidate
  (rank by spendPriority after three gates). One skill for what the Norns spin.
user-invocable: false
metadata:
  internal: true
---

# nornir — fate & schedule: process→event sources (events) + quota-aware dispatch (quota)

The Norns spin what will come: the watches that wake Brokk, and the quota that
governs which smith is dispatched.

```
assets[2]{path,load_when}:
  "assets/events.md","registered process→event sources: arming, condition→action eligibility, durable result read, wake routing"
  "assets/quota.md","resolving a matched crew-dispatch profile array from quota-axi's default TOON"
```

A change to scheduling or dispatch policy edits an asset here, not a new skill.
