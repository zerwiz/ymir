## 2026-09-17 — the private home gets the ward it never had

- **Six guards watched the public repo; the home had none — yet the home is where
  every private byte lives.** The one real leak of this day (`platform.env.prev-fill`,
  44 credentials) happened *there*, in a scratch backup swept up by `git add -A`,
  with nothing watching. `bin/hoard-guard.sh` closes that.
- **It is a hook, not a script.** Seated as `$YMIR_HOME/.git/hooks/pre-commit`,
  **git runs it on every commit** — including one made in a hurry, by a loop, or by
  an agent that has never heard of it. Verified by attempting a real `git commit`
  with no guard invoked: git refused, exit 1.
- **It catches what actually leaked**, verified by planting each: a scratch-backup
  name (`*.prev-*`, `*.bak`, `*.orig`), a plaintext secret filename, a secret shape,
  and — the evasion that would have hidden a key — **a base64 blob whose decode
  contains a PEM header**, under an innocent filename.
- **`bin/ymir-install.sh` seats it at both repos** (the `hoard-gate` step reports
  the home separately, so a dormant vault is visible), on every install layer.
- **A bypass is logged, not silent.** `hoard-guard.sh --log-bypass` appends to the
  Runes ledger when a `--no-verify` commit is detected.
- **Two stale flat paths fixed in the guards themselves.** `bin/docs-guard.sh` told
  an operator to move private docs to `$YMIR_HOME/docs/` — a path that no longer
  exists — and `bin/groa-update.sh` read `$YMIR_HOME/data/eindri-homes.md` instead of
  the hoard's. A guard pointing at the wrong door teaches the drift it exists to stop;
  `groa-update.sh` now resolves through `hoard_root`.
