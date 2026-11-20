## agents · unversioned · 2026-10-18 — the skill index is portable across machines

### Why

The skill index **did not work on heimdall**. `bin/agents/skill-index.sh` wrote
each skill's `path` as an **absolute** path — `192` of them under
`/home/<this-seat>/…` — and the index is committed to the **home repo, which syncs
to every machine**. On the second machine every one of those paths was a lie: the
finder resolved nothing, `--check` read the index as incomplete forever, and the
home went dirty on every session as the index was regenerated against the local
tree. That is exactly the fault **Rule 25** names — *a path that exists on this box
is not a path*.

### Now

- **The index is shelf-relative.** Each entry's `path` is relative to the shelf
  root named by its `shelf` (`ships · local · home · pi`), and the **reader anchors
  it to its own machine**. No machine path is written to the index at all. (An
  older absolute entry still reads, so a v1 index is not broken by this.)
- **The index and its human inventory are no longer tracked** in the home — they
  are per-machine, beside the same precedent as `.ymir-layout.yaml` — and are
  regenerated on every session start.
- **`stat` is probed, not assumed** (`stat -c %Y` → `stat -f %m`), so the freshness
  check works on BSD/macOS as well as GNU.
- `docs/security.md` states the contract Rule 25 implies: every ward check probes
  and **reports SKIP and exits 0** where a platform lacks the surface.

### Verified

- `.agents/tests/skill-index.test.sh` → **7 passed, 0 failed**; the new assertion
  fails the build if the index ever contains a `path: "/…"` machine path.
- Live: `grep -c 'path: "/' skills.yaml` → **0**; entries read
  `path: "bragi-marketing/SKILL.md"`; `skill-find.sh --where grill-me` still
  resolves an absolute path on this machine; `--check` → `index fresh: 192 skills`.
- The home: the two paths are untracked and gitignored (`12981df`), and the
  working tree is clean there.

### Files

- `bin/agents/skill-index.sh`
- `bin/agents/skill-find.sh`
- `.agents/tests/skill-index.test.sh`
- `docs/security.md`
- `bin/README.md`, `.agents/assets/agents/capabilities.md` (regenerated)
