## runtime · unversioned · 2026-09-19 — a deployed extension is told where its `bin/` is

### Why
- **The watch never armed on a deployed machine.** Every Pi extension resolved its
  distro root as `resolve(extensionDir, "../..")`. Deployed to
  `${HOME}/.pi/agent/extensions/`, that reaches `${HOME}/.pi` — a directory holding
  pi's own config and **no `bin/` at all**. So `~/.pi/bin/syn-watch-arm.sh` was
  exec'd, did not exist, and the Gná arm child died with **exit 127 before its first
  poll**. No `state/.watch.heartbeat` was written anywhere on the machine, no
  `.supervision-armed` ever appeared, and the watch was dead while every file
  listing looked correct. The Sága digest never arrived either — the turn-end guard
  spawns `${root}/bin/saga-sessionstart-run.sh` from that same root, so its runner
  was a path that did not exist.
- **A deploy that copies an extension without telling it where its own `bin/` lives
  is not a deploy.** The copy is necessarily *outside* the tree that owns `bin/`;
  nothing in the copy can discover that tree by walking up from itself.
- **The root is now recorded at deploy time.** `bin/valknut-load.sh --pi` writes one
  absolute root per line — most recent first, deduped, capped — to
  `${HOME}/.pi/agent/extensions/.ymir-root`, and `.pi/extensions/lib/ymir-home.ts`
  reads it back for all four extensions (`gna-pi-watch`, `syn-turnend-guard`, `ro`,
  `skuld-branch-supervision`). Resolution order: `BROKK_ROOT_OVERRIDE` ·
  `BROKK_HOME` · `YMIR_ROOT` → the recorded roots → `resolve(extensionDir, "../..")`.
- **A candidate counts only if it really holds `bin/syn-watch-arm.sh`.** A root that
  no longer exists — a merged-and-removed Yggdrasil worktree, an uninstalled npm
  prefix — is skipped rather than trusted. That is why the record is a *list*:
  deploying from a worktree records the worktree **and** keeps the durable root
  behind it, so a cleanup cannot strand the machine on a dead path.
- **Root and home are separate in name and in fact.** The root owns `bin/`; the home
  owns `state/` and `config/`. They are usually one tree and need not be — a private
  `$YMIR_HOME` has no `bin/` of its own, and conflating the two is exactly what made
  a deployed copy exec a path that never existed.
- **A worktree deploy no longer repoints the global contract.** `valknut-load.sh`
  symlinks `~/.pi/agent/AGENTS.md` at the tree it ran from; pointed into
  `.yggdrasil/<id>` it would die with the worktree and leave every later session
  with no contract at all. It now repoints only when the current target is already
  gone.
- **Eir carries the surface** (`bin/eir-doctor.sh`: `harness`), so a record with no
  live root is diagnosed and mended rather than discovered; `bin/valknut-load.sh
  --status` reports the same row.

### Files
- `.pi/extensions/lib/ymir-home.ts` — the resolver (new)
- `.pi/shared/extensions/{gna-pi-watch,syn-turnend-guard,ro,skuld-branch-supervision}.ts` — resolve the recorded root
- `bin/valknut-load.sh` — record the root at deploy time; guard the global contract
- `bin/eir-doctor.sh` — the `harness` surface
- `.pi/extensions/README.md` · `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` — the contract
