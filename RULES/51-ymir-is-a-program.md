# 51 — Ymir is a program; it runs globally, in the user's root agents

**This repository is the source of a program. Ymir runs GLOBALLY on the user's computer — in the root (global) agent of
every harness the user has, and in the user's home — never because a session was opened inside this checkout.**

Written 2026-11-11 at the operator's word: *"we are not working with ymir from ymir's repo. ymir are everywhere on the
computer. so the repo are just the program of ymir."* · *"this must be a rule for how we're developing ymir. ymir are a
program with a lot of features that we just ship in this mono repo."* · *"ymir are the logic. the tools. the
programs."* · *"ymir must work GLOBALLY on the users computers."*

## The law

```
laws[7]{rule,why}:
  "THE REPO IS THE SOURCE, NOT THE PLACE","the monorepo holds Ymir's logic, tools and programs; it is where Ymir is BUILT and SHIPPED from, not where it is used — a feature that only works with the cwd inside the checkout is unfinished"
  "THE ROOT AGENT IS WHERE YMIR LIVES","every harness's global agent (pi ~/.pi/agent, Claude ~/.claude, OpenCode ~/.config/opencode, Codex ~/.codex, Cursor ~/.cursor, and every future one) carries Ymir's contract, extensions, MCP doors, skills and hooks — so a session opened in ~ or in any project has all of Ymir"
  "INSTALL AND UPDATE CARRY IT","bin/engine/ymir-install.sh and bin/agents/groa-update.sh seat every root agent (bin/seat/harness-extensions-install.sh, from .agents/harnesses/); eir-doctor checks it — a feature that lands in the repo but not in the root agents on the next update is not shipped"
  "A ROOT AGENT LOADS THE RUNTIME, NEVER A WORKING TREE","the root points at the pinned runtime ($YMIR_RUNTIME_DIR, RULES/02 §7) or a copy made from it — a branch an agent left checked out is never what the user's agents run (PR #654: two checkouts, every tool twice)"
  "ONE CAPABILITY, EVERY HARNESS","a tool built for one harness (a Pi extension) is reached by the others through Ymir's MCP door (plans 183, 239) — the user's harness choice never decides which Ymir they get"
  "THE CONTRACT IS RENDERED INTO THE ROOT","the always-loaded contract is the seat render in each root agent; this repo's AGENTS.md is the page for DEVELOPING Ymir; CLAUDE.md is a link to AGENTS.md, never a second copy (plan 246)"
  "PRIVATE STAYS HOME","the program ships from here; the user's data, names, machines and secrets stay in $YMIR_HOME (RULES/04) — a global install never writes private data into a repo"
```

## How to tell a feature is done

It answers from a session opened **outside** this repository — in `~` and in an unrelated project — on every harness
the user has, after a fresh install and after an update. A feature proved only from inside the checkout is not proved.

## Seated by

`bin/engine/ymir-install.sh`, `bin/agents/groa-update.sh` (`/updateymir`), `bin/seat/harness-extensions-install.sh`
(per-harness descriptors in `.agents/harnesses/`), `bin/seat/seat-surface.sh` (the root contract), and `eir-doctor`.
The build plan is plan 248 in the home ledger (*Ymir lives in the root agents*), reconciling plans 161, 169, 183, 239
and 246.

## CHANGE LOG

- **2026-11-11** — written at the operator's word.

## Appended 2026-11-11 — the contract once, and the skills as one

At the operator's word (*"follow the rules … and ymir's rules"*), the two designs of plan 248 become law here, so no
build can do them another way.

```
laws_more[6]{rule,why}:
  "ONE CONTRACT PER ROOT","the seat render in each root agent is the one always-loaded contract; a session must never load the same law twice (measured: 47 KB render + 48 KB repo copy). The repo AGENTS.md is the developer page and stays lean"
  "CLAUDE.md IS A LINK","in every repository Ymir runs, CLAUDE.md is a symlink to AGENTS.md — one file, every harness's name for it"
  "ONE YMIR SKILL IN EVERY ROOT","each harness root lists exactly one Ymir skill, `ymir` (~/.agents/skills/ymir, linked from ~/.claude/skills/ymir); its SKILL.md is the generated index of every skill, by path"
  "THE STORE IS NEVER SCANNED","the full skill store lives outside every directory a harness searches (pi searches ~/.agents/skills and ~/.pi/agent/skills RECURSIVELY) — otherwise every description returns to every turn"
  "BOX FACTS STAY ON THE BOX","a machine's own contract sections (addresses, keys, hardware) live on that machine, never in a repo"
  "THE BUDGET IS MEASURED","what a session start injects is summed per harness by one door, and a ward refuses an always-loaded set over its budget"
```

The order of work, the measurements and the online reading behind each line are plan 248 in the home ledger.
