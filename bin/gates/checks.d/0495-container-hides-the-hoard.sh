#!/usr/bin/env bash
# THE REVIEWER'S ITEM 5 (2026-11-12) — a container Ymir ships never holds the vault. The Quadlet used to
# mount the operator's home whole, so `hodd/secrets` arrived with the age key beside its own
# ciphertext and the container could decrypt the hoard. The mask is one line; this gate is what
# keeps it, and keeps it over the same path the home mount uses.
gate container-hides-the-hoard "a shipped container that mounts the home masks hodd/secrets" \
     bash "$ROOT/bin/gates/tests/test_container_hides_the_hoard.sh"
