## install · unversioned · 2026-09-17 — the install asks with a plan, and the operator's things leave the code tree

### Why
- **The consent a real install asks for is now computed, not recited.** The old
  prompt was a hardcoded paragraph, and a paragraph cannot know the host: it named
  an Omarchy version on a Mac, promised a workspace tree that already stood, and
  never mentioned that no application had been installed at all. `bin/ymir-plan.sh`
  probes this machine and prints one row per step with its state and the reason —
  `DO · SKIP · INFO · BLOCKED · CONSENT` — across nine phases (resolve · code ·
  home · runtimes · engines · apps · wire · raise · verify). `ymir-install.sh`
  prints it at the consent prompt; `--plan` / `--dry-run` prints it and writes
  nothing; `--json`, `--phase N` and `--blocked` are there for automation and for
  reading what is holding an install back.
- **The four app surfaces are named in the plan.** hlidskjalf, odrerir, sessrumnir
  and smidja each get a row: whether the source is present, whether the web build
  exists, and — when it is absent — the honest reason (`no apps/<name> and no
  @zerwiz/<name> package`). The Electron shells are a `CONSENT` row, not a silent
  download: three shells each pull a ~100 MB runtime the web surfaces do not need.
- **The home is the operator's to choose.** `step_home` asks once, records the
  answer as machine state under `~/.config/ymir/home`, and every later script
  resolves it through `bin/hoard-lib.sh` (`$YMIR_HOME` → the r

### Files
- *(carried from the frozen CHANGELOG.md)*
