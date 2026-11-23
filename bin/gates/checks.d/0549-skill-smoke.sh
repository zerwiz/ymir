#!/usr/bin/env bash
# skill-smoke — 2026-11-22 (plan 350 D): a skill that teaches a door that is gone, or a CLI verb its help no longer
# offers, is named (the smoke reads the tree and help only; nothing a skill names is run).
gate skill-smoke "every door and CLI verb a skill names still exists" \
     bash "$ROOT/bin/agents/tests/test_skill_smoke.sh"
