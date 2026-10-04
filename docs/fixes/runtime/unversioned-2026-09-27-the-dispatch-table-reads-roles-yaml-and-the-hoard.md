## runtime · unversioned · 2026-09-27 — the dispatch table reads roles.yaml and the hoard

### Why
Plan 58, Part 1: *Dispatch — role → figure → model → seat: Python + YAML; a decision table belongs in data, not in a 1000-line script.* Plan 58's folder shape names `src/dispatch/`. The wiring (`.agents/roles.yaml`, shipped by #223) and the model (the hoard's `config/agents.yaml`) existed; the ONE reader that resolves an errand through them did not. This is that reader, behind the engine's CLI.

### Files
- `src/ymir_runtime/dispatch/__init__.py`
- `src/ymir_runtime/dispatch/table.py`
- `src/ymir_runtime/dispatch/registry.py`
- `src/ymir_runtime/dispatch/resolve.py`
- `src/ymir_runtime/dispatch/__main__.py`
- `src/ymir_runtime/__main__.py`
- `src/ymir_runtime/__init__.py`
- `src/pyproject.toml`
- `src/ymir_runtime/tests/test_dispatch.py`
- `bin/engine/ymir-engine.sh`
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
### What
**The decision table, read as data** (`src/ymir_runtime/dispatch/`):

```
dispatch[4]{module,owns}
  "table.py","`.agents/roles.yaml`: role → figure · craft · tools · keywords · dispatch — the WIRING, declared in data. Declares no role; a table claiming `model_from` other than `hoard`, a role with no figure, or a figure nobody rostered is a loud refusal naming the key"
  "registry.py","the hoard's model, read at runtime from `$YMIR_HOME/config/agents.yaml` (schema-validated by the config layer); a model REQUEST is resolved by `bin/model-resolve.sh` and its TOON read back"
  "resolve.py","one errand → one `Resolution` (role · figure · craft · tools · model · harness · effort · seat · kind, with provenance)"
  "__main__.py","`python3 -m ymir_runtime.dispatch [resolve|roles|choose|request]` — the layer's own door face"
```

**The chain.** role (explicit key/figure, or chosen from task text by the table's
own keywords) → figure → tools → the hoard's configured model for that figure →
the YAML's declared local/online harness → the seat type. The seat type is read,
not re-decided: `container.declared_from_brief` owns the `Isolation: herdr|utgard`
parse and `resolve()` reuses it; an explicit `--isolation` wins.

**The engine's CLI gains a `dispatch` verb** proving the resolution without adding
a fifth verb to `seat · status · send · stop`:

```
ymir-engine.sh dispatch developer --toon
  dispatch[1]{role,figure,craft,tools,harness,model,seat,kind}:
    "developer","sindri","code — build, refactor, fix, test","pi","…","herdr","ship"
```

**Two refusals, both naming the key (the config layer's voice, #226):** an unknown
role/figure lists every name the table knows; an absent hoard config names
`agents.<figure>.model` and the exact path — never a silent default.

### Honesty — how model resolution rides the fleet registry
`bin/model-resolve.sh` owns the *resolution loop* (fuzzy request → concrete
harness/provider/model, the bash loop). The Python module **calls that door** —
`HoardModels.request()` runs `bin/model-resolve.sh resolve "<text>"` and parses
its TOON row — and never re-implements a line of it. The *configured* road is a
LOOKUP, not resolution: the hoard already carries a concrete `provider/model`
token, so the module reads `agents.<figure>.model` (through the config layer's
schema validation) and applies only the rule the YAML itself declares
(`harness.local · harness.online · harness.local_providers`). No model value ever
ships in the tree, and the provider-rename-per-harness stays with the harness
binder (`bin/agents-config.sh apply`), not a second copy here.

### Proof (run, not asserted)
- **Two synthetic hoard YAMLs → two resolutions, tree untouched:**
  `YMIR_AGENTS_YAML=/tmp/hoard-a/config/agents.yaml python3 -m ymir_runtime dispatch developer --toon`
  → `llama.cpp/model-alpha@q4`; the same against hoard B → `llama-swap/model-beta@q8`;
  `git status --porcelain` shows only the intended edits.
- **Unknown role refuses loudly:** `python3 -m ymir_runtime dispatch captain` →
  `refused: unknown role or figure 'captain' … known roles: …` exit 1.
- **A live model request rides the door:**
  `python3 -m ymir_runtime.dispatch request "qwen 3.6 iq3"` → the fleet registry's
  own TOON answer (`local","pi","llama-swap","qwen3.6-35b-a3b@iq3_s","high"`).
- **Unit tests beside the module:** `python3 -m unittest` — 158 tests OK (34 new in
  `src/ymir_runtime/tests/test_dispatch.py`); system python3 (no jsonschema) skips
  the validator-gated rows cleanly (31 skips).
- `bash -n bin/engine/ymir-engine.sh` clean.
- No new dependency: the layer reads YAML/JSON through the declared config layer.

**Correction (2026-09-27, Forseti's #229 review — appended, the original stands).**
The review held the seal on three items; all mended in the same pass:
- The dispatch section is `### 7.6` (level 3), ordered after `### 7.5`, with its
  blank line — not `## 7.4` (a duplicate of the grants' 7.4).
- The suite count on the rebased head is **175 OK (42 skipped, system python3)**,
  not 158.
- `resolve()` now derives `root` from `env` when none is passed
  (`root = resolve_paths(env).root`), so the table and the model registry read
  the SAME root — the rootA/rootB divergence the judge demonstrated is closed.
