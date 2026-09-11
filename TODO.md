# TODO — Allfather's orders

Source: the Allfather's words this session. Each item states what was asked, what
exists now, and what remains. Nothing here is claimed done unless verified.

---

## A. Omarchy-first + integration (NEW — this round)

### A0. Omarchy-native skill — DONE
- **Asked:** build a skill so the system knows Omarchy, and load the omarchy skill.
- **Done:** `.agents/skills/ymir-omarchy/SKILL.md` — the two laws (never edit
  `/usr/share/omarchy/`; Hyprland owns placement), host detection, the
  monitor/scale coordinate trap, the amdgpu GPU crash + mitigation, desktop-app
  placement, safe-customisation table, discovery. Registered in the skill index.
- **Also done:** `.agents/skills/ymir-thjazi/SKILL.md` — Þjazi (herdr-first),
  protocol floors (14+ panes, 0.8.0 spaces), install/verify.

### A1. Ymir learns the user's machine — DONE
- **Asked:** "omar should learn more and more of the user's setup ... if they're
  making package and changes to their machine."
- **Done:** `bin/omarchy-sense.sh` records a comparable snapshot
  (omarchy version, explicit package count, config-file count, monitors, scale)
  to `state/omarchy-setup.json` and **diffs it**, reporting what changed.
  Verified: detects an Omarchy version change and a package-count change.
- **Remains:** richer learning — record *which* packages and *which* config files,
  not just counts, so advice can be specific.

### A2. Update when Omarchy updates — DONE
- **Asked:** "if updates are happening to omarchy omar needs to update."
- **Done:** `bin/omarchy-hook-install.sh` installs an Omarchy `post-update.d`
  hook that re-runs the sensor after every `omarchy update`. Installed and run.

### A3. Þjazi installed at install time — DONE
- **Asked:** "install herdr if user don't have it in the installation."
- **Done:** `bin/herdr-ensure.sh` (status/ensure) verifies the version against the
  floors and installs via the pinned SHA-verified installer, else accepts tmux.
  Wired as `step_backend` in the installer. Verified: `backend OK herdr`.

### A4. Monitor / placement logic was WRONG — FIXED
- **Asked:** "we booted the election on this screen so the omarchy logic are not right."
- **Root cause:** Electron reports **logical** size (physical ÷ scale). Omarchy runs
  this panel at 1920×1200 **scale 1.5** = a 1280×800 logical desktop; my old
  1440-wide window with a `min 960` clamp filled the whole screen.
- **Done:** geometry is now logical and clamped to the work area; the apps prefer
  a **non-primary** display when one is attached and fall back to primary. Two
  dashboards never stack on the same secondary. Documented in `hlidskjalf-ui.md`.
- **Note:** this machine has **one** connected display (eDP-1); DP/HDMI are
  disconnected, so the fallback is the correct behaviour here.

## A5. Native machine problems

### A5a. Electron GPU crash — DIAGNOSED, mitigated
- 9 crashes in 27s, all `--type=gpu-process`; kernel: `amdgpu ... Not enough
  memory for command submission`; iGPU VRAM 453/512 MB. Not an OOM, not our code.
- **Done:** `YMIR_DESKTOP_DISABLE_GPU=1` in `scripts/electron.sh` adds
  `--disable-gpu --disable-gpu-compositing`. Verified: app stable, no new crashes.
- **Remains:** decide the default (auto-detect small VRAM iGPU, or leave GPU on).

### A5b. Double-launch bug — FIXED
- **Asked:** "we saw that we had 2 electrons running ... we can start several in a row."
- **Root cause:** `.bin/electron` is a node shim that **spawns** the real binary;
  `$!` tracked the shim, so `is_running` was false while Electron was alive, and a
  second launch stacked. `stop` had the same flaw.
- **Done:** identity is now the Electron command line (`--user-data-dir`), and the
  launcher runs the real binary directly. `stop` kills every matching pid.
- **Verified:** launch #2 reports `already up`; exactly **1** MAIN process.

### A5c. Per-machine state was being shared — FIXED
- **Asked:** "secrets/state must be in env files or data files — state's not
  getting shared [correctly]."
- **Finding:** `.agents/memory/kaia.engram` (+ `-wal`/`-shm`), and
  `well/*.jsonl` were **tracked and pushed** — 5.6 MB of one machine's private
  memory, plus volatile SQLite sidecars that can corrupt a fresh clone.
- **Done:** untracked (files kept on disk), gitignored
  (`.agents/memory/kaia.engram*`, `*.db`, `well/*.jsonl`), and the contract is now
  stated in `.agents/memory/README.md`.
- **Remains:** the already-pushed history still contains the data. Decide whether
  to purge it from git history.

---

## B. Install hardening (DONE, verified)

### A1. Electron apps must start after install — DONE (verify on fresh machine)
- **Asked:** "after the installation are done both electron apps should start so
  the user sees the applications."
- **Done:** `scripts/electron.sh` self-heals the Electron binary (npm 11 gates
  postinstall → `ensure_electron_binary` runs `install.js`, else extracts the
  cached zip); `ymir-install.sh` gained `step_desktop` (`--no-desktop` to skip).
- **Verified:** `desktop OK "raised Hlidskjalf + Smíðja"`; validator shows both up.
- **Remains:** test on a truly fresh checkout (no `node_modules`).

### A2. Validate the installation — DONE (extends further)
- **Asked:** "we should have a validation of the installation script so we
  validate that everything is running and installed correctly."
- **Done:** new `bin/ymir-validate.sh` — 10 live checks (prereqs, sandbox, gate API,
  SPA, Bifrost, cron, smidja.db, desktop, memory well, runes) with `--json`;
  wired as `step_validate` in the installer.
- **Verified:** all required checks pass on the live system.
- **Remains:** extend to per-engine checks (treehouse, no-mistakes, hermes,
  Utgard run/sandbox round-trip).

### A3. Make the whole thing more stable — OPEN (started)
- **Asked:** "we need to make this more stable."
- **What is fragile today (observed, not guessed):**
  1. **Stale pid files lie.** `nornir-cron-start.sh` reported "running pid=310173
     jobs=4" while `ps` showed no nornir process; the pid was alive but unrelated.
     The validator now asks the owner script, but the *script itself* can report a
     dead scheduler as running.
  2. **Electron postinstall is silently blocked** by npm 11 `allowScripts`. Now
     self-healed in `electron.sh`, but any other package with a postinstall
     (esbuild was also flagged) has the same trap.
  3. **`sandbox` needs a re-login** for the docker group — the only check that
     cannot be self-healed in-session; must be surfaced clearly, not as a failure.
  4. **Installer idempotency** not yet proven by running it twice back to back and
     diffing the result.
  5. **No rollback/journal** if a step fails mid-install.
- **Remains:** address 1–5; add a smoke test that runs install → validate → re-run
  install and asserts a clean, unchanged second pass.

---

## B. Doctrine alignment (owed from the earlier drift)

### B1. `installation.md` is stale — OPEN
- The asset documents **9 steps**; a real install now emits **13 rows**
  (`prereqs`, `memory-well`, `tree`, `engines`, `hermes`, `sandbox`, `memory`,
  `smidja`, `loaders`, `register`, `services`, `desktop`, `validate`); `--check`
  emits 10 (the runtime steps are skipped when nothing runs).
- It says `bun` is *system-level, reported not installed*; the installer now
  installs it via `prereq-ensure.sh`.
- Missing: consent gate, `prereq-ensure.sh`, `smidja-bootstrap.sh`,
  `ymir-validate.sh`, `--no-desktop`.
- **Remains:** rewrite the asset to match, or revert the code to match doctrine.

### B4. The install-hardening work is not yet committed — OPEN
- `bin/ymir-install.sh`, `bin/ymir-validate.sh`, `scripts/electron.sh` are changed
  in the working tree on `main` (plus the `install-validate` worktree holds the
  same edits). **Remains:** commit, merge, push. Verify on a fresh checkout first.

### B2. Decide the doctrine deviations — OPEN (needs the Allfather)
- Consent gate, self-healing bun/uv, smidja bootstrap, desktop launch, validation:
  are these **approved** additions to the install contract? Once answered, encode
  the answer in the asset so the map stops disagreeing with the code.

### B3. `bun` install policy — OPEN
- `installation.md` says report-only; code installs it. Pick one.

---

## C. The memory well (engram) — BLOCKED on a fact

### C1. Find the real engine — OPEN
- **Finding:** `pip install engram` is the **wrong package** — PyPI's `engram` is
  Benjamin Beilharz's alpha scientific project (pulls torch/triton). The code needs
  `from engram import Engram` (`.agents/skills/galdr/assets/memory-well.md`,
  `bin/mimir-bridge.py`).
- The store exists (`kaia.engram`, 1.3 MB) and was seeded 2026-09-11 ("engram 1.30",
  370 episodes) — so the engine *did* exist once.
- **Remains:** the Allfather names the source (git URL / package / where it was
  installed). Then wire it into the self-healing path. Until then `memory` stays an
  honest WARN, never a fake fix.

### C2. Python provisioning — machinery READY, no target yet
- `uv` is installed; `prereq-ensure.sh python <X.Y>` can fetch any interpreter in
  user space (verified: Python 3.12.14 fetched in 23 s). Ready for C1's target.

---

## D. Governance: skills must load more often — DONE (5 layers)

- **Asked:** "how can we make so the skills get loaded more often?" → "do all".
- **Done:** (1) `AGENTS.md` `governed[6]` path→asset table + `manual[]` rows;
  (2) session digest prints `ASSET ROUTING`; (3) `galdr`'s
  `disable-model-invocation` removed; (4) enforced seatbelt
  `bin/syn-asset-pretool-check.sh` (denies a governed edit until its asset is
  read, relayed by the Pi extension); (5) `compliance-check.sh` `assets` gate
  fails on a governed path changed without its asset.
- **Verified:** the new gate caught its own change (stale harness README) and
  blocked a live governed edit. compliance 9/9. Pushed in `744f9df`.

---

## E. Repo / remote hygiene — OPEN

### E1. Remote mismatch
- `pr-ops` documents `Way-Of/ymir`; this checkout's `origin` is `zerwiz/ymir`.
  Pushes have gone to `zerwiz/ymir`. **Remains:** confirm the intended remote.

### E2. Operational files are tracked and always dirty
- `.agents/memory/kaia.engram{,-shm,-wal}` are tracked but mutate at runtime, so
  `git status` is permanently dirty and `yggdrasil.sh merge` refuses until they are
  dealt with. **Remains:** decide — gitignore them, or keep them tracked and accept
  the churn.

---

## F. todo extension — this list's own home

- **Asked:** "so we get the todo extension."
- No working `tasks` CLI exists: `.agents/tools/tasks-cli.ts` is a README stub and
  `@ywir/tasks` 404s on npm. `.tasks.toml` points at `data/backlog.md`, which does
  not exist.
- **Remains:** decide the storage — (a) create `data/backlog.md` in the documented
  format and use it, or (b) build/install a real `tasks` CLI. This file is the
  interim record.

---

## Verified state right now (2026-09-11)

```
validate[10]{check,status,detail}:
  prereqs PASS · sandbox WARN(docker group) · gate-api PASS · spa PASS
  bifrost PASS · cron PASS · smidja-db PASS · desktop PASS
  memory WARN(engram engine) · runes PASS
all required checks pass (2 warnings)
```

Up: SPA :3888 · gate API :3889 · Bifrost :4603 (lmstudio, keyless) · cron ·
Hlidskjalf + Smíðja desktop apps.
