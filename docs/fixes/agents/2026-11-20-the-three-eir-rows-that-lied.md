## agents · unversioned · 2026-11-20 — the three Eir rows that lied, and the mend that could not clear itself

### Why

Eir's verdict is only worth the two things it promises: a red row is a real fault, and `fix` clears
the row it named. Three rows broke that promise, found the night before at the operator's word to
mend every fault on the board.

| Row | What it said | What was true |
|---|---|---|
| `gates` | red: "installed hook is stale" | the seated hook ran **no ward at all**, silently |
| `runtimepin` | red: "names a Ymir tree but is not in `config/units.yaml`" | the unit was the app's own, under the apps home |
| `agentroad` | red, and its fix wrote a unit file only | the row cannot go green until the unit is enabled |

### 1. `gates` — a false red in front of a hook that ran nothing

`bin/gates/guards/fixes-guard.sh --install` copied `.githooks/pre-push` into
`<git-dir>/hooks/pre-push`. The shipped hook resolved its root as
`root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`; inside `.git/hooks` that answers `.git`,
which holds no `bin/gates/guards.sh`, so the copy printed
`pre-push: no guards door in this checkout; skipping` and exited 0 — every ward, skipped, in
silence. Meanwhile `s_gates` asked whether that copy contained `git rev-parse --show-toplevel`, a
string the shipped hook had since dropped, so the row was red for ever while the gate did nothing.

The install is now what the hook's own header always said it should be:

```bash
git config core.hooksPath .githooks
```

A **relative** `hooksPath` is resolved against the worktree that is pushing — git runs a hook with
its working directory at that worktree's top level (measured 2026-11-20) — so a Yggdrasil worktree
runs its own `.githooks/pre-push` and never the main tree's. That is the fault the 2026-10-20 fix
chased, cured at the root instead of patched by re-copying.

The copy road stays, only where the config cannot be written, and it is correct there too: every
shipped hook now resolves its root with `git rev-parse --show-toplevel`, keeping the
source-relative answer as a fallback for a tree git cannot read.

`s_gates` judges what is installed rather than searching text:

- `core.hooksPath` (asked through `git rev-parse --git-path hooks`, git's own answer) must seat a
  pre-push that **is** `.githooks/pre-push` byte for byte, or
- a hook in another hooks directory on purpose must still resolve the pushing worktree, call
  `bin/gates/guards.sh` and run `bin/gates/branch-current.sh`.
- A copy that has drifted from the shipped hook is a stale gate, not a pass.

One consequence had to be met in the same change. `secret-guard.sh --install` generated its **own**
pre-commit body (weaver plus public, docs, private, vault and confidential wards) while
`.githooks/pre-commit` carried a different one (NDA gate, secret scan, retired-path gate). Once
`hooksPath` names `.githooks`, that generated body is dead — and writing it would have overwritten a
**tracked** hook in the working tree, because `git rev-parse --git-path hooks` answers `.githooks`
once `hooksPath` is set. So:

- `.githooks/pre-commit` is now the one pre-commit and carries both sets, so seating hooks by
  `hooksPath` loses no refusal;
- `secret-guard.sh --install` copies that file (one home for the hook text, as the pre-push hook was
  taught on 2026-11-11) and writes nothing when `hooksPath` already names `.githooks`.

`bin/engine/ymir-install.sh` (`step_gates`) and `.agents/skills/lifecycle/smoke_test.sh` asked a
fixed `.git/hooks` path; both now ask git, so the install layer and the smoke test judge the hooks
that actually run.

### 2. `runtimepin` — Eir did not know the apps home

`ymir-rodd.service` runs `~/.local/share/ymir-apps/rodd/current/start.sh`, the home
`bin/apps/app-path.sh` gives every app that left Ymir's tree in the split of 2026-11-19. The unit
also names the pin (`Environment=YMIR_RUNTIME_DIR`), so `names_ymir()` was true and, because the
unit is not in `config/units.yaml`, `units.sh check` called it `UNREGISTERED`. Worse, `units.sh
write` retargets unregistered units that name a Ymir tree: it would have moved that unit onto the
pin, which no longer carries `apps/rodd` — a mend that breaks the window it mends.

A unit or launcher whose paths live under the apps home is the app's own. `bin/engine/units.py`
resolves that home through the one door, `bin/apps/app-path.sh` (`--home` and `--list`), never by
writing a path; such a unit is reported `ok` with its reason and is neither stray nor retargeted.

The row's detail also lied in a second way: with the units green it printed "every unit and
launcher is on the pin" while the row was red, because since 2026-11-15 the row also asks
`pin-refresh`. It now names the pin's own verdict (measured: the pin stood 28 commits behind main).

### 3. `agentroad` — a mend that could not clear its own row

The fault text said `bin/engine/units.sh write ratatoskr-relay`, which only writes the unit file.
The row stays red until the unit is enabled, so Eir printed an instruction that could not mend the
fault it named. The mend writes the unit **and** enables and starts it, which the `safe` class in
`config/surfaces.yaml` covers ("re-seats the wake-and-return loop … never touches a live session"),
and the fault text names both commands:

```bash
bin/engine/units.sh write ratatoskr-relay && systemctl --user enable --now ratatoskr-relay
```

### Proof

`bash bin/agents/tests/test_eir_true_mends.sh` — 15 checks, all passing:

- a throwaway repository is installed through the shim and receives a push **from a worktree**; the
  stubbed ward door's own words (`WARD-RAN`) appear in the push output, which is the proof the
  seated hook is no longer silent;
- a copy in `<git-dir>/hooks` does the same, so the fallback road resolves its root correctly;
- `s_gates` accepts `hooksPath` plus the shipped hook, accepts a byte-identical copy, and refuses
  both a drifted copy and an empty hooks directory;
- a fake unit under a temp apps home (`YMIR_APPS_HOME`) is judged `ok — an app's own unit, under the
  apps home` by `units.py check`, and named `app-owned`, not retargeted, by `units.py write
  --dry-run`;
- the agentroad mend is called with stub doors and both the write and the
  `enable --now ratatoskr-relay` are recorded.

Also run in this change: `bin/agents/tests/test_eir_mends.sh` (5 passing) and
`bin/gates/tests/test_nda_guard.sh` (37 passing), because the hooks it exercises were re-seated.

> [!IMPORTANT]
> The machine's own `gates` row is still red until Eir's `fix gates` runs on it: this errand mends
> the install, and the seat re-seats itself through `fix`. The stale copy at
> `<git-dir>/hooks/pre-push` is left in place as text; under `hooksPath` git no longer reads it.

### Files

- `.githooks/pre-push` — the root is resolved (`git rev-parse --show-toplevel`, source-relative
  fallback), and the header now names the install road.
- `.githooks/pre-commit` — the one pre-commit: weaver, five staged wards, no-delete, secret scan,
  NDA gate, retired-path gate; root resolved the same way.
- `.githooks/commit-msg` — the same root resolution, so a copy is not blind either.
- `bin/gates/guards/fixes-guard.sh` — `--install` sets `core.hooksPath .githooks`; the copy road
  survives only where the config cannot be written.
- `bin/gates/guards/secret-guard.sh` — `--install` copies `.githooks/pre-commit` and never writes
  over the tracked hook.
- `bin/agents/eir-doctor.sh` — `s_gates` judges the install, `gates_detail` names it,
  `f_agentroad` writes **and** enables, `runtimepin_detail` names the pin's verdict.
- `bin/engine/units.py` — an app's own unit, under the apps home (`bin/apps/app-path.sh`), is `ok`
  and never retargeted.
- `bin/engine/ymir-install.sh`, `.agents/skills/lifecycle/smoke_test.sh` — ask git where the hooks
  are instead of assuming `.git/hooks`.
- `bin/agents/tests/test_eir_true_mends.sh` — the proof.
- `docs/features/the-wards-the-delivery-gate.md`, `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` — the
  hook install and the three rows, described as they now behave.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #842
