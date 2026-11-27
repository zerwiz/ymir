# Who merges is the fleet's rule, not the shipped core's

**Date:** 2026-11-28 · **Component:** time (the Sága head's fixed core)

## What broke

The fixed core every session reads (`bin/time/saga-head-core.md`) said *"the Allfather seals the merge, never an
agent"*. RULES/08 (2026-11-21) says a PR with green gates is merged by the heart's keeper with no human seal. The heart's
keeper followed the fixed core and refused to merge green PRs; the contradiction stopped the fleet's merges.

## The fix

Who merges is a fleet's own policy, so the shipped core no longer states one. It says the merge follows the fleet's
rule in the home's overlay (`config/eindri-core.md`, printed into every brief on top of the core) and keeps the one
universal line: a worker never merges its own branch. A fleet's overlay names its merger; this fleet's says the heart
fixes and merges.
