## gate · unversioned · 2026-10-04 — three tools assumed a flat extension tree, and the gates said so

### Why

PR #281 moved three extensions into directories. It merged with **three red gates**,
and every one was a tool in this repo that still assumed the old flat shape. **A
restructure is never only the thing it moves** — it is also every tool that looked
at what it moved.

| gate | what it said |
|---|---|
| `capability` | `.agents/assets/agents/capabilities.md` is STALE — the count went 39 → 31 |
| `inventory` | `bin/README.md` is STALE |
| `ext-smoke` | `skuld-branch-supervision LOAD FAILED Cannot find module …/.pi/shared/e…` |

### The one that mattered

`bin/gates/capabilities.sh:28` counted registered tools with a **flat glob**:

```bash
grep -rhoE 'pi\.registerTool\(\{|name: "[a-z_]+"' .pi/shared/extensions/*.ts
```

`ro/`, `constellation/` and `skuld-branch-supervision/` became folders, and a flat
`*.ts` glob stopped reaching them. **The eight tools were not lost — the register
stopped counting them.**

**That is worse than a stale register.** A stale register fails a gate, loudly. A
wrong one passes, and every future number copied from it is wrong. The count is
**39 again**, and no tool was ever missing.

### Fix

- **`bin/gates/capabilities.sh` enumerates recursively**, excluding tests, so it reads the
  tree the way pi reads it.
- **`tools/extension-smoke.mjs` resolves an extension the way pi resolves it** — a
  direct `.ts`, or a directory whose entry point is `index.ts`. It hard-coded
  `` `${name}.ts` ``, so it was testing a shape pi had already stopped loading and
  reported LOAD FAILED for a tree that was correct.
- **Both regenerated**: the capability register and `bin/README.md`.

### The pattern, named so it is not repeated

**Three tools in one repository enumerated the extension tree three different ways**,
and none of them was the way pi does it. The gates did not fail because the
restructure was wrong — they failed because it was the first change that made the
difference visible.

> A change of SHAPE must be followed by a sweep of every tool that reads that shape.
> The register, the inventory and the smoke test are not bystanders; they are
> consumers, and a consumer left on the old assumption is a silent defect.

This belongs with Rule 13 §9 — *"a gate that only ever passes is worse than no gate"* —
because that clause is what made these three failures visible within one merge rather
than after the next three.

### Verified

```
$ bash bin/gates/capabilities.sh --check    → PASS   ("Pi extension tools",39)
$ bash bin/gates/inventory.sh --check       → PASS   (401 files)
$ node --experimental-strip-types tools/extension-smoke.mjs
    extension_smoke{called,verified_not_executed,broken,skipped} = 9, 17, 0, 2
$ bash .agents/tests/pi-extensions.test.sh   → PASS
$ bash bin/seat/valknut-load.sh --check           → PASS
```
