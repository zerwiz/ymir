## skills · unversioned · 2026-11-04 — the index carries the templates and the requirements

### Why

`bin/skills/manifest.sh` grew a reader for a manifest's LIST fields (`templates:` and
`requires:`) and then never called it: `ylist` was defined and dead. The tree ward that watches
for exactly this caught it in CI on a fresh clone —

```
"bin/skills/manifest.sh","DEAD FUNCTION","ylist is defined and never called (RULES/16)"
```

— and *not* on the developer's checkout, where the same ward reported `0 findings` for the same
commit. A ward that reads differently in CI than in a worktree is worth knowing about; the code
fault it found is worth fixing either way.

### Now

The caller exists, and it earns its place: the DERIVED index now records the two fields a reader
needs before fetching anything — the shapes a skill ships and the skills it names:

```yaml
  - name: hearth-keeping
    templates: [fix-note.md]
    requires: [the-elder]
```

`index.yaml` is still generated from manifests only, and still never hand-edited.

### Verified

- `bash bin/gates/guards/dead-code-guard.sh check` → `"314","0","0"` (was `1` finding, on a
  fresh clone of the branch).
- `bin/skills/manifest.sh index --root <fixtures> --out <tmp>` → the three skills, with
  `templates: [fix-note.md]` on `hearth-keeping` and `requires:` on `rune-counting`.
- `bin/gates/tests/test_skills_mcp.sh` → 27 checks, 0 failures.

### Files

- `bin/skills/manifest.sh`

## CHANGE LOG

- **2026-11-09** — the note was carried into the integration branch whole, its history with it.
