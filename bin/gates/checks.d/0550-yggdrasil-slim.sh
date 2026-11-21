#!/usr/bin/env bash
# yggdrasil-slim — the slimmer worktree is opt-in, and a refusal leaves nothing behind.
#
# `yggdrasil.sh create --skip <dir>` / `--slim` leave a vendored folder out by sparse-checkout.
# The default create is unchanged, and every refusal (no .worktree-slim, an unsafe folder, a file
# that cannot be skipped) removes the worktree and branch it made. The fix note is
# docs/fixes/forge/2026-11-20-a-slimmer-worktree.md.
gate yggdrasil-slim "a slimmer worktree is opt-in, the default is unchanged, and a refusal leaves no worktree or branch" \
     bash "$ROOT/bin/forge/tests/test_yggdrasil_slim.sh"
