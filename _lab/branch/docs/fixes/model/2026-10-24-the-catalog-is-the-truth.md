# The catalog is the truth — one door, one line at boot

**2026-10-24.** Component: `bin/model/catalog.sh` (new), `bin/agents/einherjar-spawn.sh`,
`bin/time/saga-session-start.sh`, `AGENTS.md`.

## What was wrong

`pi` already knew every model this machine can serve — `pi --list-models` answered **496 models across five
providers**, including the 30 `opencode-go` models — and nothing told an agent so at boot. Four places held
four opinions instead:

```
opinions[4]{place,said}:
  "pi's live catalog","496 models — the truth"
  "bin/model/model-resolve.sh","opencode-go/deepseek-v4.1-flash -> harness: pi (a typed table, not the catalog)"
  "bin/agents/einherjar-spawn.sh","its own parse of the catalog, which refused harness pi + an opencode-go model"
  "AGENTS.md","a prose provider table naming LM Studio on :1234 — a door the Allfather retired"
```

A session therefore rediscovered the answer by probing, one refusal at a time, all morning.

## The fix

- **`bin/model/catalog.sh`** — one door over `pi --list-models`: the TOON list, `--providers`,
  `--has <provider/model>`, `--check` (which fails loudly when the catalog cannot be read at all).
- **The spawn guard calls it** (`catalog_has` → `catalog.sh --has`), so no second parse survives.
- **The session digest prints a MODEL CATALOG block**: the door, its provider counts, and the rule that a
  listed model is pi's to serve.
- **`AGENTS.md` appends the correction**: LM Studio retired, the door named as the authority — the old table is
  kept as the record of what was believed (Rule 06).

## Proof

```
catalog.sh --check                        -> 496 models, PASS
catalog.sh --has opencode-go/deepseek-v4.1-flash  -> listed
einherjar-spawn.sh … --harness pi --model opencode-go/deepseek-v4.1-flash --dry-run
   -> harness: pi · model: opencode-go/deepseek-v4.1-flash · accepted
```
