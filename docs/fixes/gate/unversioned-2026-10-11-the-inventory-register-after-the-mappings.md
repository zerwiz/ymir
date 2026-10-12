## gate · unversioned · 2026-10-11 — the inventory register, re-run after the fixes-guard mappings

### Why

`bin/README.md` is DERIVED from `bin/` — every door, its first line, its callers and
its line count (`bin/gates/inventory.sh`). The change beside this note added the
`tools/tickets-mcp/*` → `odrerir` row to `bin/gates/guards/fixes-guard.sh`, which
changed that file's line count and its place in the index. The register was not
re-run in the same pass, so `inventory --check` failed on the PR:

```
inventory --check: bin/README.md is STALE — run bin/gates/inventory.sh
```

One row of the gates, and the only one: this is the third time in a day the same
ordering has bitten (edit `bin/`, regenerate LAST). Named here rather than quietly
fixed, because the trap is the real finding — see ymir/43.

### What

`bin/gates/inventory.sh` re-run until `--check` reported current — twice, because
neither register generator converges in one pass (the caller count reads its own
output; the first run is always one short — ymir/43).

### Verified

- `inventory.sh --check` → `bin/README.md is current (416 files)` ·
  `.agents/backend/README.md is current (175 files)`.
- The PR's own CI: every row PASS except `inventory`, which was the row this note
  closes — so the change is bounded to what the register says about itself.

### Files

- `bin/README.md` — regenerated
