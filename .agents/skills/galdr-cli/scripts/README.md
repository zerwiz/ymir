# Galdr Scripts — compliance and TOON tooling

Executable checks for the Galdr/Tyr gates. Both are Galdr-style: TOON output on
stdout, structured errors, no prompts, `--version` fast path, idempotent.

```
scripts[2]{file,purpose}:
  "toon-check.py","validate TOON blocks (header count/fields vs rows; ... = elided)"
  "compliance-check.sh","run all gates: toon, naming, mocks, syntax, json, sync"
```

## Usage

```
python3 .agents/skills/galdr-cli/scripts/toon-check.py <file-or-dir> [...] [--quiet] [--json]
bash    .agents/skills/galdr-cli/scripts/compliance-check.sh [--quiet] [--json]
```

Exit codes: `0` success, `1` violations, `2` usage error.

## What compliance-check.sh enforces

```
checks[8]{id,what}:
  "toon","TOON blocks valid in galdr SKILL.md + assets + tyr SKILL.md + AGENTS.md"
  "naming","no imported terms (Allfather/Yggdrasil/Eindri) in AGENTS.md + bin/ (observer exempt)"
  "mocks","no mock/stub/placeholder/TODO in the shipped runtime (bin/)"
  "syntax","bash -n on bin/*.sh; node --check on .opencode/plugins/*.js"
  "json","every runtime JSON parses"
  "sync","galdr-cli/assets mirrors tyr-check/assets"
```

## TOON block convention

```
type[count]{field1,field2}:
  "value","value"
```

A row of `...` marks an elided excerpt and is reported `ELIDED` (not a failure).

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr-cli/SKILL.md`.
- Extend a gate by adding to `compliance-check.sh` and a row to its `checks` block.
