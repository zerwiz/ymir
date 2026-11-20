# The registry that answered a traceback — and a seat that could not be named

**Dated:** 2026-10-24 · **Component:** agents · **Branch:** `fix/registry-needs-yaml`
**Found on:** sleipnir (the hand — Termux/Android, Python 3.13, Pi 1.4.0)

## The symptom

The seat could not be named, so Gróa kept answering `seat-identity: error: sleipnir has no seat identity`:

```
bin/agents/seat-identity.sh set sleipnir dvalin
  error: registry not built — run: name-registry.sh scan

bin/agents/name-registry.sh scan
  Traceback (most recent call last):
    File "<stdin>", line 102, in <module>
    File "<stdin>", line 56, in scan
  AttributeError: 'NoneType' object has no attribute 'safe_load'
```

## Two faults

**1. A missing dependency told as a traceback.** `name-registry.sh` guards the import —

```python
try:
    import yaml
except Exception:
    yaml = None
```

— and `entries()` handles `yaml is None` with a named error. But `scan()` called `yaml.safe_load` **unguarded**,
so on a seat without PyYAML the one command that could fix the seat died in an `AttributeError` naming neither
the dependency nor the remedy. A door that answers a traceback is the same fault as a door that answers
nothing.

**2. The hand owed PyYAML and nothing installed it.** `prereq-ensure.sh` composes a surface per prerequisite
(bun, uv, mcp, engram, python) and **python packages the naming law needs were not among them**. Rule 05: a
core feature that needs a dependency installs it in every platform layer, or the layer is drift.

## The fix

- `need_yaml()` in `name-registry.sh`: names the dependency, names the remedy, exits **2** — called at the top
  of `scan()`.
- `ensure_pyyaml()` in `prereq-ensure.sh`, reached as `prereq-ensure.sh pyyaml`: present → ok;
  else install via pip (`--user --break-system-packages`) and re-prove the import; else say exactly what
  failed. It reuses the engine's existing python/pip discovery (`engram_python`, `engram_ensure_pip`) so there
  is still one owner of "which interpreter can install".

## Verification

```
bin/name-registry.sh scan                        → scanned 109 names   (the registry builds)
PYTHONPATH=<fake yaml that raises ImportError> \
  bin/name-registry.sh scan                      → "error: PyYAML is not installed …" + "help: … pyyaml"  (no traceback)
bin/engine/prereq-ensure.sh pyyaml               → "pyyaml","present","Python 3.13.13"
```

## Found in passing — a name collision the registry now reports

```
collision	heimdall	host,subsystem	host
collisions	1
```

`heimdall` is registered both as a **host** and as a **subsystem**. The naming law says one figure owns one
role; this one owns two, and the registry now says so out loud. Named here, not silently tolerated, and not
fixed by this branch — it is a naming decision, which belongs to the Allfather, not to a commit.

## Restart

None. Both doors are read at call time.
