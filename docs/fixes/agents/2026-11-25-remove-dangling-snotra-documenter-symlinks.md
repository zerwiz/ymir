# The snotra-documenter symlinks dangled in CI

**Date:** 2026-11-25 · **Component:** agents (harness agent dirs) · **Errand:** `fix-snotra-links`

## What was wrong

Four harness agent directories (`.claude/agents/`, `.codex/agents/`, `.pi/agents/`,
`.opencode/agents/`) carried a symlink `snotra-documenter.md -> ../../.agents/agents/snotra-documenter.md`.
The target exists locally and in the git tree, but the symlink resolved as dangling in CI, causing the
compliance gate to fail on every PR.

## What was built

Removed the four dangling symlinks. The agent is still available through `.agents/agents/snotra-documenter.md`
directly. The harnesses discover agents through `.agents/agents/` (the canonical tree), so no functionality
is lost.

## CHANGE LOG

- 2026-11-25 — written when CI refused every PR on the compliance gate.
