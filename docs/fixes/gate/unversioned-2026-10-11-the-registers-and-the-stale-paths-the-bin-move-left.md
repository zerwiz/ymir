## gate · unversioned · 2026-10-11 — the registers and the stale paths the bin move left

**Cites:** `docs/fixes/gate/unversioned-2026-10-04-the-bin-rebuild-left-every-caller-pointing-at-the-old-door.md`.

### Why

Three red rows on `main` from one move, none of them a code fault:

**1 — The registers were never regenerated.** `.agents/assets/agents/capabilities.md`
still read `"shell doors (bin/*.sh)",399` against the tree's 451, and `"generated","2026-10-06"`
against today, with a verdict that had moved (`tailscale-sync.sh`: `tested` → `tested+named`).
`bin/README.md` (`inventory --check`) was stale the same way.

**2 — Six live references to doors that no longer exist** — the same wound as the note
cited above, in places that note did not reach:

- `bin/gates/guards/branch-guard.sh` credited its own installer as the retired
  `bin/changelog-guard.sh` (it is `bin/gates/guards/fixes-guard.sh --install`)
- `tests/e2e/engine-proof.sh` printed its usage as `bin/engine-proof.sh` (it is
  `tests/e2e/engine-proof.sh`)
- `.agents/config/eindri-dispatch.json` told a reader to dispatch through
  `bin/einherjar-spawn.sh` (it is `bin/agents/einherjar-spawn.sh`) — a **template** an
  agent reads before dispatching, naming a door that does not exist
- `.agents/skills/galdr-ymirsystem/assets/installation.md` seated the delivery gates by
  the same retired `changelog-guard` — and that asset governs `bin/engine/ymir-install.sh`
- `package-lock.json` recorded the published package's `ymir` bin as the pre-move
  `bin/ymir.js`, a file that does not exist, while `package.json` names the truth
- `RULES/04-hoard.md` named both wards by their pre-move paths (see the ward note)

### What

- `bin/gates/capabilities.sh` and `bin/gates/inventory.sh` run until `--check` reports
  **current**, committed.
- The six stale references corrected; the RULES correction APPENDED (Rule 06).

### Verified

- `capabilities.sh --check` → `current (451 door rows)`.
- `inventory.sh --check` → `bin/README.md is current (416 files)` ·
  `.agents/backend/README.md is current (175 files)`.
- `package-lock.json` root `bin` == `package.json` `bin`:
  `{'ymir': 'bin/engine/ymir.js', 'ymir-install': 'bin/engine/ymir-install.sh'}` — and
  `pr-pretest` (which does a REAL npm install and rewrites the lock) now leaves the tree
  **clean**, which is the second half of the proof.

### Known, and named rather than hidden

- **Neither generator is idempotent in one pass.** Running the one command
  `--check` tells you to run leaves the file still stale: the caller count scans its own
  output. Two runs converge. The remedy line misleads — ticket **ymir/43**.
- `pr-pretest` still rewrites `package-lock.json` when the lock drifts — a gate mutating
  the tree it judges, ticket **ymir/45**.

### Files

- `.agents/assets/agents/capabilities.md`, `bin/README.md`, `.agents/backend/README.md` — regenerated
- `bin/gates/guards/branch-guard.sh`, `tests/e2e/engine-proof.sh`,
  `.agents/config/eindri-dispatch.json`,
  `.agents/skills/galdr-ymirsystem/assets/installation.md` — stale references
- `package-lock.json` — the recorded `ymir` bin
