#!/usr/bin/env bash
# nda-write.sh — Claude Code PreToolUse(Write|Edit|MultiEdit): the NDA gate, RULES/04, 2026-11-12.
# Refuses a write into the PUBLIC Ymir tree whose content or path carries a company, client or NDA-project
# name. The matcher is bin/gates/guards/ndalib.py — the same module the git hooks and CI use. A write
# outside a Ymir checkout, or into the home, passes. It always prints a decision or nothing.
for r in "${YMIR_ROOT:-}" "$HOME/ymir"; do
  [ -n "$r" ] && [ -r "$r/bin/gates/guards/nda-guard.py" ] && exec python3 "$r/bin/gates/guards/nda-guard.py" hook
done
exit 0
