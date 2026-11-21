#!/usr/bin/env bash
# 2026-11-21 — one door carries the fallback for every hosted service. Four fake steps are forced
# down in turn and the next one must answer, naming itself; a key must never reach the output.
gate bifrost-chain "the model door falls through its chain step by step and names the step that answered" \
     bash "$ROOT/bin/bridge/tests/test_bifrost_chain.sh"
