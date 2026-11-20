## gate · unversioned · 2026-11-04 — the canary assembles its home path

### Why

The skills-door test seeds a canary skill to prove the ward catches a machine path — and it wrote
that path LITERALLY into `bin/gates/tests/test_skills_mcp.sh`. The file ships in a PUBLIC
repository, so the fixture carried exactly the shape Rule 07 forbids in a shipped surface:

```
"config","no hardcoded models, providers, or user paths (Rule 07)","FAIL","hardcoded: bin/gates/tests/test_skills_mcp.sh(path)"
```

The compliance `config` gate caught it in CI, which is the gate doing its job — a test that hunts
a pattern and then commits the pattern is a small, sharp lesson: **the fixture is part of the
tree it tests.**

### Now

The canary still carries a home path — that IS the shape under test — but it is ASSEMBLED at run
time from two `printf`s, so no literal user path exists in the tracked file. The fixture keeps
its teeth: the ward still classifies the row as `machine path`, and the test still asserts all
eight canary classes.

### Verified

- `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` → no `FAIL` rows (was
  `config … FAIL … (path)`).
- `bin/gates/tests/test_skills_mcp.sh` → **27 checks, 0 failures**, the canary caught in
  `machine path · address · port · name · mailbox · phone · bench table · model id`.
- `bin/gates/guards.sh` → 25 wards PASS.

### Files

- `bin/gates/tests/test_skills_mcp.sh`

## CHANGE LOG

- **2026-11-09** — the note was carried into the integration branch whole, its history with it.
