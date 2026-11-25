# harness · 2026-11-25 — Hermes is named with the harnesses

## What was wrong

Ymir's pages listed the harnesses it works in as pi, Claude Code, OpenCode, Codex and Cursor. Ymir also seats itself in
Hermes from the same pin (the contract, the MCP doors, the skills shelf, the Sága head and the worker wake), so every
such list left one root agent out.

## What changed

Hermes is named, with the same weight, where the claim holds:

- `AGENTS.md` and `RULES/51` — a dated section each, correcting the root-agent list (append-only);
- `README.md` — the harnesses that take the seat when pointed at the repository;
- `docs/features/roots-load-the-runtime.md` — Hermes's root, what it gets, and what is not yet proven;
- `docs/features/brokk-the-primary-agent.md`, `saga-the-session-start.md`, `build-a-fleet.md`;
- `package.json` — the description's harness list, and the keywords `hermes` and `hermes-agent`.

## What was not claimed

A tell into a Hermes session that holds the arm is posted through its gateway (plan 369 item 1, merged), but no live
end-to-end run is recorded yet, and the pages say so. App
READMEs were read and left alone: Smíðja runs only pi inside a run, and Sessrúmnir is a desktop over pi and oh-my-pi,
so naming Hermes there would be untrue. Bilskirnir already names Hermes.

## Proof

```bash
git grep -n "Hermes" -- AGENTS.md RULES/51-ymir-is-a-program.md README.md docs/features/roots-load-the-runtime.md
node -e 'const k=require("./package.json").keywords; console.log(k.includes("hermes") && k.includes("hermes-agent"))'
bin/seat/hermes-seat.sh --check     # the seat these pages describe
```
