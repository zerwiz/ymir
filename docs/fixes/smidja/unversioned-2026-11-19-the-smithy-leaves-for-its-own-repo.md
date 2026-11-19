## smidja · unversioned · 2026-11-19 — the smithy leaves for its own repo, with its history, and installs into its own home

### Why
The Allfather: *"time to separate the mono repo"*, *"i dont wanna them come into the apps folder anymore if installed
they need their own places"*, *"we can not lose anything"*, and *"start with the smidja"*. It is one of the three things
he will mainly use (plan 08).

### What moved
- `apps/smidja-factory/` (the factory) and `apps/smidja/` (the engine this house ran) → `zerwiz/smidja`, cut with
  `git filter-repo`: the factory at the root, the engine at `engine/`. 78 commits there, every one of the 58 that touched
  either folder here among them. One declared change: the engine's config names `engine/` where it said `apps/smidja/`.
- `.agents/skills/smidja-factory` (the skill shelf's link into the app) left with it. The app's `activate.sh` puts the
  books on the harness-wide shelf instead (`~/.pi/agent/skills/smidja-factory`), which the one Ymir skill indexes for
  every harness.
- `bin/desktop/smidja-{board,bootstrap,lib,observe}.sh`, `tools/web/systemd/smidja.service` and `scripts/smidja`
  **stay** as Ymir's side of the joint. They find the smithy through the one resolver, so they follow it into its home
  unchanged (plan 08 had them leave; keeping them is simpler and loses nothing).

### The ties
71 code lines named the two folders. Each has a decision:
- re-pointed through the resolver: the root `justfile` now goes through `scripts/smidja`; the icon tool, the sandbox's
  factory, the bootstrap and the window-buttons test find the smithy through the resolver;
- removed: the npm workspace, the dependency, the shipped files, 15 lines of the lock, the packaging seam;
- guarded: the release now skips the viewer when the smithy is not in the tree (it would have died with exit 19);
- kept on purpose, and written down in `config/split/smidja.kept.tsv`.

The subsystem map and the governed table name what stays here (`bin/desktop/smidja* | scripts/smidja`); the citation
check honours an app-provided skill, as the skill index already did.

### Found on the way
- **The viewer climbed into Ymir** for its hearth: `App.vue` imported `midgard/design-system/ember.js` by climbing five
  folders up, the seam that broke on 2026-09-18. It imports its own byte-identical copy (and `ember.d.ts`);
  `bin/apps/tests/test_shared_copies.py` keeps them equal.
- **`apps.sh` restarted a unit that was not the app's.** A fenced test restarted the live viewer running from the pin (no
  call was held; it came back healthy on the same release). It now restarts only a unit whose WorkingDirectory or
  ExecStart lies in the app's own home.
- **`update --all` would have installed every moved app on every seat.** It now installs a missing app only when the
  registry says `install_default: true` (the smithy, which every seat carried in the tree); Hvergelmir is the operator's
  choice.

### Proof
- `split-ledger.py verify smidja`: files 230/230 (one declared change), history 58/58, records 27/27, 0 ties owed —
  **nothing lost**.
- From the cut repo into a fenced apps home: `apps.sh install smidja` built the viewer, stamped the prompts, ran
  `--check` green, flipped, and `activate.sh` seated `smidja` and `smidja-mcp` on PATH and the MCP in pi's set (57 s).
- A real run from the **installed** smithy, in a project with no engine of its own: run `debb3ab3`, `success`, 9 tool
  calls, gate passed. The run worked in the project; its config copy (prompt paths absolute) sits beside its trace.
- `no-delete-guard`: 231 removals accepted as a move; any other deletion is still refused.

### Owed
- Push `zerwiz/smidja`, its September head tagged `pre-split-2026-09` first — held for the one PR.
- The move record in the home.
- On each seat after the release: `apps.sh install smidja` (Gróa's update does it, through `install_default`), then the
  second-machine acceptance and `--on` across machines.
