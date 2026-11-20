#!/usr/bin/env bash
# ssh-keys-chmod — 2026-11-20: the key sync sets a mode only when it is wrong, so the identity watch
# stops firing every fifteen minutes on a file nobody changed.
gate ssh-keys-chmod "the authorized-keys sync chmods only a wrong mode, so an unchanged file raises no identity alert" \
     bash "$ROOT/bin/host/tests/test_ssh_keys_no_needless_chmod.sh"
