# every harness drinks through the well door, and carries pi's one set

**Date:** 2026-11-10 · **Component:** install (with runtime: `bin/bridge/a2a-mcp.sh`)

## What was wrong

- `bin/bridge/a2a-mcp.sh install` (called by `step_a2a` in the installer, and by Eir's `mcp` mend) wrote an
  `engram` stdio server — `engram-mcp --db <hoard>/memory/kaia.engram` — into pi and opencode. A write through
  it landed in the seat's own file, skipped the gateway journal (`bin/bridge/mcp-gateway.sh`, :8316), and never
  reached the heart.
- `step_memory` counted `"engram"` in the harness configs as its health metric, so the leak read as health.
- Eir's `s_mcp` failed a seat whose opencode config did NOT bind `engram` — it enforced the leak.
- The templates carried it too: `.pi/mcp-adapter.json.example` seeded a direct `engram`, and the loader's merge
  re-added it on every run.
- `bin/bridge/mcp-config.sh write` replaced both pi MCP files wholesale with the four gateway doors, dropping every
  other server the seat held (the mesh bridge, the ymir door).
- Nothing in Ymir wrote Claude Code's, Cursor's or Codex's MCP config: each was empty or hand-copied, so the
  harnesses drifted from pi and from each other.
- Claude Code reads only `CLAUDE.md`, never a project's `AGENTS.md`; this repo's contract lives in `AGENTS.md`.

## Why

The law, stated 2026-11-10: **engram is Kaia's engine only.** Every harness — pi, opencode, claude, cursor,
codex, hermes — reaches memory through the well door, never engram directly. And every harness carries the
SAME server set as pi's `~/.pi/agent/mcp-adapter.json`, minus engram, generated from that one source.

## Fix

- `bin/bridge/mcp-config-seat.py` (new) + `bin/bridge/mcp-config.sh seat [--check]` / `harness <name>`: one set
  (pi's, the direct engram dropped, `well`/`bolthorn`/`skuld` on the gateway), written per harness in its own
  format — pi JSON, opencode `mcp{}`, Claude user scope through `claude mcp add-json --scope user`, Cursor JSON,
  Codex inside one marked block of `config.toml`; Hermes has its direct engram pruned (its adds stay with
  `bin/seat/hermes-seat.sh`). A named merge: only the set's names and a stale engram move; each changed file is
  backed up. A server carrying a literal secret (an inline `clientSecret`, a token) is not copied to another
  harness — it is named instead. An absent harness is a clean skip. `gmail`, `drive` and `docs` are OUT of the
  set for every harness, pi included (the Allfather, same day): removed where found, never seated
  (`YMIR_MCP_RETIRED` replaces the list). No template or generator in the repo emitted them.
- `mcp-config.sh write` is now the pi half of the same named merge, never a wholesale replace.
- `bin/bridge/a2a-mcp.sh`: wires `well` (the gateway door) instead of `engram`, and drops a direct engram it finds.
- `bin/engine/ymir-install.sh`: `step_a2a` says so; `step_memory` seats every harness and counts the WELL DOOR,
  reporting a direct engram as a WARN.
- `bin/agents/eir-doctor.sh`: `s_mcp` requires `/mcp/well` and fails on a direct engram; `f_mcp` also seats.
- `.agents/migrations/0020-the-well-door.sh`: an update heals the seat's `$HOME` files once.
- `.pi/mcp-adapter.json.example` drops `engram`; `opencode.json.example` names the door `well`.
- `.claude/hooks/load-agents-md.sh` (new) injects `$CLAUDE_PROJECT_DIR/AGENTS.md` as SessionStart
  `additionalContext`, skipping when `CLAUDE.md` links to or `@AGENTS.md`-imports it.
  `bin/seat/harness-extensions-install.sh` copies it and wires ONE named SessionStart entry in
  `~/.claude/settings.json` (backup kept; `--check` reports it).
- `bin/mcp/ymir-mcp.py`: ten doors the pi extensions had and other harnesses lacked —
  `brokk_branch_outcomes`, `skuld_plan`, `skuld_ticket`, `constellation_list/card/ask`, `logretta_stack`,
  `excalidraw_diagram`, `excalidraw_app`. `--selftest` counts from the server's own registry.

## Proof

- Sandbox `HOME` with stub harnesses: `seat --check` named every drift (exit 1); `seat` dropped the engram from
  pi, opencode, codex and hermes, kept the operator's own servers and tables, held the inline-secret server, and
  left a backup per changed file; a second `seat --check` reported every file current; the written
  `config.toml` parses with `tomllib`.
- The Claude wiring in a sandbox: `--check` stale → install adds exactly one entry, keeps the operator's other
  hooks and permissions → `--check` current → a second install adds no second entry.
- The hook: a project with no `CLAUDE.md` gets the contract; an `@AGENTS.md` import and a symlink both skip; the
  `python3` fallback answers without `jq`.
- `bash -n` on every changed shell file; `python3 -m py_compile` on the two Python doors;
  `bin/mcp/ymir-mcp.py --selftest` lists 46 doors; each new door was called once on a live seat.

## Not done

- `.pi/extensions/ymir-well.ts` still drinks over the HTTP bridge on `:4602` (`bin/bridge/mimir-bridge.sh`,
  which on a `hand` is the door to the heart). It is not an engram MCP server, so it is left as it is; whether it
  should go through the gateway journal is a separate question.
- `logretta_sit`, `excalidraw_tickets`, `excalidraw_servers` have no CLI face yet; `context_left` and
  `skuld_branch_report` are pi-session state.
- `bin/seat/ymir-mcp.py` is an older copy of the door and is untouched.

## Appended 2026-11-10 (second) — the second half: the Claude hooks, the law, and the arm

The first half above seated the MCP set. This half seats the house's Claude hooks on **install and
update**, writes the Eindri-only law, and mends two measured arm faults.

### The hooks, on install and update

- `.claude/hooks/eindri-only.sh` (new) — `PreToolUse(Agent|Task)` denies Claude's own subagents and
  names `bin/agents/eindri-start.sh`. `.claude/hooks/ymir-arm.sh` (new) — a global `Stop` hook
  (`asyncRewake`) that resolves the house from `~/.pi/agent/extensions/.ymir-root` and no-ops inside
  the Ymir repo, so a Claude seat in ANY project takes a wake.
- `bin/seat/harness-extensions-install.sh` now wires all THREE user-scope Claude hooks (AGENTS.md
  loader, Eindri-only, global arm) as named entries: idempotent, one backup per run, and `--check`
  reports each. It also reports the house's project-scope file by parse (it is auto-loaded in-repo,
  not mirrored into user scope).
- `bin/engine/ymir-install.sh` `step_loaders` now CALLS `harness-extensions-install.sh` (it never
  did before — the hooks and extensions were committed but never seated by install), and checks it
  in `--check`.
- `bin/agents/eir-doctor.sh` gains a `claudehooks` surface: healthy on a host without Claude, a
  named failure when a Claude seat's three hooks are stale, mended by running the installer.
- `.agents/migrations/0021-the-claude-hooks.sh` (new) seats them into a home installed earlier.
  Gróa's update already runs `ymir-migrate apply` and `harness-extensions-install.sh`.

### The law

- `RULES/49-workers-are-eindri.md` (new) — every worker is an Eindri; no harness spawns its own
  subagents; the refusal is the user-scope hook; fall back to inline work or ask the Allfather,
  never a shadow worker. Indexed in `RULES/README.md` and cross-linked from `RULES/02-agents.md`.
- `AGENTS.md` *Dispatch-first* gains an appended dated section; `CLAUDE.md` (new) is the canonical
  `@AGENTS.md` pointer, so Claude reads that law natively.

### The arm faults (measured 2026-11-10)

- **`bin/pi/syn-watch-arm.sh` (a):** a live owner skipped the acquire block and the client attached
  anyway, so a session that never held the helm still got wakes. Now a hard gate: attach only when
  the recorded owner IS this session's pid (the acquire contract), else read-only and exit 0.
- **(b):** every `Stop` spawned a new client and older clients of the same session waited beside it,
  so one signal rewoke the session five times. A new client now retires its own session's older
  clients (verified live by `/proc/<pid>/cmdline`, not by pid alone); another session's clients are
  untouched behind the helm gate.
- `bin/gates/tests/test_arm_client_helm.sh` (new) proves both with stubbed sessions in a throwaway
  home: a stranger helm is refused and writes no pidfile; a held helm retires the two older stubbed
  clients and records the new one. 5/5 pass.

### The MCP packet

- `bin/mcp/ymir-mcp.py`: `skuld_branch_report` is now a door (durable `skuld-branch-outcome.sh
  append`; the branch's conversation merge stays the extension's). Named skips remain honest:
  `context_left` (pi session state), `logretta_sit` (orchestrated inside the extension, no CLI),
  `excalidraw_tickets`/`excalidraw_servers` (logic in the extension's TS). `--selftest` now reports
  **47 doors**.

### Proof (this half)

- Throwaway `HOME` with stub Claude settings: `--check` stale for all three hooks → install adds one
  entry each (keeps an unrelated `echo keepme` hook and a `permissions` block) → second install all
  current, no duplicates.
- `bin/mcp/ymir-mcp.py --selftest` prints `doors: 47` and names `skuld_branch_report`.
- `bin/gates/tests/test_arm_client_helm.sh` → 5 PASS, exit 0.
