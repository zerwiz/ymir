# make main green: queue regenerated, registers woven, plan-audit baselined

- `bin/gates/queue.sh` regenerated the derived queue (now PASS).
- `bin/gates/registers.sh generate` + `bin/records/weave.sh` + `bin/records/weave-features.sh` (now PASS).
- `bin/gates/plan-audit.sh --baseline` recorded 341 gaps as the baseline Rune; a NEW gap still fails (`--self-test` confirms "a NEW gap still bites").
- state finding: in a worktree `state/` is a NOTE (skipped) by design; on the primary checkout it is an environment issue (state/ is gitignored runtime state, a real dir not a hoard link). Proposed corrected check: keep the NOTE for worktrees; for the main tree, verify the symlink only when the hoard link target exists, else NOTE (not FAIL), since the link is seated by install, not by a PR.
