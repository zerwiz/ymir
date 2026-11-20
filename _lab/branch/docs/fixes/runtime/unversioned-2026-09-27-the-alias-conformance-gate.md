## runtime · unversioned · 2026-09-27 — the alias-conformance gate: a rename can no longer break a seat silently

### Why
Plan 51 (multi-machine operations), Part 2 §6, *The models*: the fleet's alias
vocabulary is a contract — a seat's registry (`~/.pi/agent/models.json`) names the
models it will ask for, and the rails (the forge's heavy rail and each body's
local rail) are what serve those names. Renaming a rail alias that a body still
names breaks that body silently, and until now nothing checked it. The law was
written; the gate was missing.

### What
**The gate — `bin/gates/checks/model-alias-check.sh` (new).** It reads every reachable seat's
registry over the tailnet ring (resolved from `fleet.json`, never a literal IP),
asks every reachable rail what it serves (its written presets **and** the live
`/v1/models`), and verifies every alias a provider block names resolves — on the
forge's rail or on a body's local one. A name no reachable rail serves is a
**missing** alias: the gate FAILs, prints the seat + provider + alias + rail, and
**exits non-zero**. The rail key resolves at runtime (env → the hoard vault →
the local root pi `auth.json`) and is never written into the tree.

**Offline honesty.** A seat that cannot be reached is reported `offline` — never
a FAIL — and every reachable seat is still verified. A rail that answers with an
empty set is likewise no evidence, so its aliases fall to `offline`, not
`missing`. Exit is non-zero only for a genuine unresolved alias.

```
$ bin/gates/checks/model-alias-check.sh            # whole reachable ring, TOON
model_alias_seats[4]{seat,state,served_aliases}:
  "whynot","ok","5"
  "zerwizserver","ok","0"
  "omarchy","offline","0"
  "heimdall","ok","49"
model_alias_offline_seats[1]{seat,reason}:
  "omarchy","seat unreachable"
model_alias_check[4]{fact,value,note}:
  "verdict","pass","every named alias resolves (or its rail is offline)"
  "checked","162","aliases named by reachable seats"
  "missing","0","aliases no reachable rail serves"
  "offline","1","seats or aliases reported offline, never a FAIL"
```

**The wiring — the rename road cannot drift unnoticed.**
- `bin/model/model-placement.sh` now runs the gate for this seat and reports an
  `alias_conformance` row; its new `check` mode exits 1 on an unresolved alias
  (`YMIR_ALIAS_CHECK=off` is the loud opt-out).
- `.agents/skills/lifecycle/smoke_test.sh` gains check **14d `alias`**: it runs
  the gate `--local` so the smoke test stays deterministic on any seat, and FAILs
  when this seat names an alias no rail serves.
- `.agents/skills/lifecycle/SKILL.md` records the new check beside topology and
  version.

### The proofs (run, not asserted)
`tests/e2e/alias-conformance-proof.sh` — offline, fixture-driven; a command, not
a claim:

```
$ bash tests/e2e/alias-conformance-proof.sh
alias_conformance_proof[4]{case,result,note}:
  "healthy-registry","PASS","exit 0"
  "unserved-alias","PASS","exit 1, names seat+alias"
  "renamed-rail-preset","PASS","exit 1, the rename is refused"
  "offline-honesty","PASS","ghostseat offline, verdict pass"
alias_conformance_proof_verdict[1]{verdict}:
  "PASS"
```

**Live, on the real fleet** (`bin/gates/checks/model-alias-check.sh`):
- Healthy ring: `verdict pass`, `checked 162`, `missing 0`, `omarchy offline`
  (exit 0) — an unreachable seat is `offline`, never a FAIL.
- A deliberately-broken registry (one ghost alias appended to the seat's
  `llama-swap` block, `YMIR_ALIAS_REGISTRY=/tmp/… --local`): `verdict FAIL`,
  `missing 1`, row `"heimdall","llama-swap","qwen3.6-35b-a3b@ghostRenamed-quant","local:heimdall"`,
  exit 1.
- A **rename** of a preset in the rail's written contract while the seat still
  names the old one (`YMIR_RAIL_PRESET=<temp> YMIR_ALIAS_NO_LIVE=1 --local`):
  `verdict FAIL`, `missing 1`, `"heimdall","llama-swap","qwen3.6-35b-a3b@iq3_s","local:heimdall"`,
  exit 1 — the rename road is refused.
- Smoke test both ways: `"alias","OK"` on the healthy tree; with the broken
  registry override, `"alias","FAIL","heimdall names alias … "` and smoke exit 1.

`bash -n` clean on every touched script; compliance `assets`/`config`/`syntax`
gates pass.

### What this does NOT yet own
- **No rename *guard*, only a rename *gate*.** The gate refuses a broken state
  once it exists; it does not intercept the edit. A pre-push hook could run it
  before the tree leaves — named here, not built.
- **Remote seats' written presets are not read.** Over the ring the gate reads a
  remote seat's registry and its *live* rail; only the local seat's preset INI is
  read as the written contract. A rename on a remote rail that has not restarted
  is caught on that seat's own smoke test, not from here.
- **Non-rail providers are skipped.** A provider with no `baseUrl`, or one that
  addresses neither loopback nor a fleet host, is not judged — it is not a rail
  alias road.

### Files
- `bin/gates/checks/model-alias-check.sh` (new — the gate)
- `bin/model/model-placement.sh` (runs the gate; `check` mode)
- `.agents/skills/lifecycle/smoke_test.sh` (check 14d `alias`)
- `.agents/skills/lifecycle/SKILL.md` (the check is documented)
- `tests/e2e/alias-conformance-proof.sh` (new — the offline proof)
