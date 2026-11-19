## bilskirnir · 2026-11-19 — the hall leaves for its own repo, with its history, and installs into its own home

### Why
The Allfather: *"time to separate the mono repo"*, *"i dont wanna them come into the apps folder anymore if installed
they need their own places"*, *"we can not lose anything"*. Bilskirnir is one of the three things he will mainly use
(plan 06).

### What moved
`apps/bilskirnir/` (286 files) → `zerwiz/bilskirnir`, cut with `git filter-repo --subdirectory-filter`: every one of
the 23 commits that touched it here, authors and dates kept. **Its data home did not move**: it was already outside the
tree (`BILSKIRNIR_DATA_HOME`, else `$YMIR_HOME/bilskirnir`; plan 275 S5), and each release links to it.

### It stands alone
The hall reached out of its own folder five ways; installed in its own home, each would have found nothing.
`scripts/ymir-root.sh` finds Ymir where it is (`YMIR_RUNTIME_DIR`, the pin, the old tree), and the hall says in words
when it is not:
- the home resolver (`setup.sh`) and the app library (`start.sh`);
- the house voice door (`server/src/voice.ts`): "The house voice comes from Ymir, and Ymir is not installed on this
  machine";
- the design system, which the web face now carries as its own byte-identical copies (`web/src/house-design/`; the
  name avoids the hall's own `design/` ignore rule, which hides upstream's local notes). `bin/apps/tests/test_shared_copies.py`
  keeps them equal to `midgard/design-system`.

The contract: `app.yaml`, `install.sh` (setup without the launcher, then the web face and the server built; `--check`),
`activate.sh` (the launcher, after the flip), `stop.sh`, `uninstall.sh` (never the data home) and CI.

### Faults found on the way
- **The launcher would have vanished.** `setup.sh` seated the entry only when the pin carried `apps/bilskirnir`. It now
  also follows the apps home's `current` link, and runs the hall's own `start.sh` when Ymir's `ymir-app` is absent.
- **Every first install failed its own check** (already true on main): a fresh agent config is written by `yaml.safe_dump`
  in flow form, `browser: {cdp_url: '…'}`, and the pin check matched only the block form.
- **Every second setup failed its own check** (already true on main): the merge drops the quotes of `default: "<model>"`,
  and the model check insisted on them. Both checks now read the value, never the layout.
- **`apps.sh` handed an app the tree it ran from as `YMIR_RUNTIME_DIR`**, so a test install wrote a worktree's
  `ymir-mcp.py` into the agent's config. It now hands over the pin when the seat has one.

### Ymir's side
`ymir-app` (what the launcher runs) and the stopwatch's stop find the hall through the resolver; so do Eir's surface,
the voice toolbox's model and provider doors, the icon tool and two tests. `step_bilskirnir` installs it with
`apps.sh` once it has left; the release builds its face only while it is in the tree; the two hall gates run its own
tests only while it is here (its CI runs them after). Lines kept on purpose are in `config/split/bilskirnir.kept.tsv`.
The registry: `contract: 1`, `moved: zerwiz/bilskirnir@<sha>`, `install_default: heart, dev` (the roles that installed it
in the tree; a sweep installs it nowhere else).

### Proof
- `split-ledger.py verify bilskirnir`: 286/286 files, 23/23 commits, 18/18 fix notes, 0 ties owed — **nothing lost**.
- The live data home (`~/Documents/ymirhome/bilskirnir`), snapshotted read-only before and after (68,257 entries: every
  file hashed, every table counted): **the same**. The tests never used it: they ran on a synthetic data home and a fenced
  Ymir home in scratch.
- From the cut repo into a fenced apps home: install built, `--check` green, flipped, `activate.sh` seated the launcher
  (`ymir-app bilskirnir`, the bronze mark); an update across a new commit; a rollback.
- The installed hall raised headless from its own home: Nanna's gateway up, the face and the server built, `:8787`
  answering — `/api/health` 200 JSON, the guarded routes 401 JSON (not HTML), the page titled *Bilskirnir · the hall of
  rooms*; then lowered cleanly. (It refused to touch a stranger on its agent's port, the operator's own Hermes on 8642 —
  rightly; the test gave its agent 8742.)

### Owed
Push `zerwiz/bilskirnir` (held for the one PR); the move record in the home; on each heart and dev seat after the
release, `apps.sh install bilskirnir` (Gróa's update does it, through `install_default`); the window exercised in
DevTools and the second-machine acceptance; the `hq` MCP's harness face, if the Allfather wants it.
