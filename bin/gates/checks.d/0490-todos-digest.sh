#!/usr/bin/env bash
# todos-digest — Sága's to-do count is HIS list (his half and the house-kept half, named apart) with
# the voice ledger as its own count; three open items report three, and an unreadable list says unable,
# never zero (2026-11-16).
gate todos-digest "the session digest counts the Allfather's real list, names the halves apart, keeps the voice ledger separate, and never prints 0 over a list that holds open items" \
     bash "$ROOT/bin/voice/tests/test_todos_digest.sh"
