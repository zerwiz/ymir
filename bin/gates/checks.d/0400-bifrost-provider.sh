#!/usr/bin/env bash
# PLAN 275 item 22 — OmniChat lost every model at once because Bifrost fell back to a retired
# LM Studio when no key was in the env file. The fallback is now the vault, then the local
# rail, and the model list comes from the catalogue (so v4.1 appears).
gate bifrost-provider "the model bridge never falls back to lmstudio, reads its key through the vault, and lists the catalogue" \
     bash "$ROOT/bin/bridge/tests/test_bifrost_provider.sh"
