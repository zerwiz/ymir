#!/usr/bin/env bash
# identity — Rule 04/39 — a commit publishes an account, never a private mailbox.
#
# `--check`, not `--base`: on a pull request the checkout is the host's merge commit, and the
# ward's merge-aware path (HEAD^1..HEAD^2) is the only range that is the contributor's own. It
# names its own scope in the row, and reports its own SKIP where no merge base exists.
gate identity  "Rule 04/39 — a commit publishes an account, never a private mailbox" \
     bash "$ROOT/bin/gates/guards/identity-guard.sh" --check
