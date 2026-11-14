#!/usr/bin/env bash
# codex-plugin — the Codex tool catalog, shell syntax, install and refresh contract.
codex_checks() {
  local door
  for door in bin/engine/ymir-install.sh bin/agents/groa-update.sh bin/bridge/ymir-plan.sh; do
    bash -n "$ROOT/$door" || return 1
  done
  node --test "$ROOT/tests/test_codex_plugin.mjs" "$ROOT/tests/test_codex_install.mjs" "$ROOT/tests/test_codex_wsl_well.mjs"
}
gate codex-plugin "the Codex tool catalog, shell syntax, install and refresh contract" codex_checks
