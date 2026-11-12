# The well door for every harness — one MCP set, seated into pi, opencode, Claude, Cursor, Codex and Hermes

Ymir's memory — the well — has one engine, and that engine belongs to Kaia. Every agent harness you use reaches
the well through a **door**: your machine's MCP gateway, which keeps a journal of each write and carries it to
the heart. A harness that talked to the engine directly would write into a file on your own machine, and the rest
of your fleet would never see what it learned.

There is one list of MCP servers: pi's (`~/.pi/agent/mcp-adapter.json`). One command copies that list into
every other harness on your machine, in each harness's own format, with the record servers (`well`, `bolthorn`,
`skuld`) pointed at the gateway.

## What you need

- Ymir installed, so the gateway answers on `127.0.0.1:8316`.
- The harnesses you use. A harness that is not installed is skipped. The command says so and does not fail.
- `python3`. For Hermes it also needs PyYAML.

## The commands

```bash
bin/bridge/mcp-config.sh seat --check     # what would change, per harness — changes nothing (exit 1 if anything would)
bin/bridge/mcp-config.sh seat             # seat every harness present
bin/bridge/mcp-config.sh harness claude   # print the set in one harness's format (pi|opencode|claude|cursor|codex)
```

Where each harness gets it:

- **pi:** `~/.pi/agent/mcp-adapter.json` and `mcp.json`, both of them.
- **opencode:** `~/.config/opencode/opencode.json`, plus the repo's `opencode.json` if it has one.
- **Claude Code:** your user scope, through `claude mcp add-json --scope user`.
- **Cursor:** `~/.cursor/mcp.json`.
- **Codex:** `~/.codex/config.toml`, inside one marked block that Ymir owns.
- **Hermes:** a direct engram entry is removed from `~/.hermes/config.yaml`. `bin/seat/hermes-seat.sh` adds the
  rest of the set.

The installer runs `seat` in its memory step. An update runs it once more through migration `0020-the-well-door`.
`bin/agents/eir-doctor.sh fix` runs it when the `mcp` surface fails.

## Claude Code and AGENTS.md

Claude Code reads `CLAUDE.md` and never a project's `AGENTS.md`. Ymir ships a SessionStart hook,
`.claude/hooks/load-agents-md.sh`. The hook hands Claude the project's `AGENTS.md` at the start of a session.
It does nothing in three cases: the project has no `AGENTS.md`, its `CLAUDE.md` is a link to `AGENTS.md`, or
`CLAUDE.md` imports it with an `@AGENTS.md` line. `bin/seat/harness-extensions-install.sh` copies the hook to
`~/.claude/hooks/` and adds one SessionStart entry for it to `~/.claude/settings.json`. Nothing else in that
file changes. Run it with `--check` to see whether the entry is there.

## Limits

- **Retired servers are removed everywhere.** `gmail`, `drive` and `docs` are not part of the set for any
  harness, pi included. `seat` removes them where it finds them and never adds them. Set `YMIR_MCP_RETIRED`
  (comma-separated) to change that list.
- **It merges by name and never rewrites a whole file.** Only the names in the set, plus a stale `engram`, are
  touched. Servers you added yourself stay. Every file it changes is first backed up as `<file>.bak-<time>`.
- **A literal secret never travels.** A server in pi's list that carries a secret inline (an OAuth `clientSecret`,
  a token in `env`) is not copied to the other harnesses. The command names it so you can move the secret to a
  reference (`$VAR`).
- **Codex:** Codex already gets the `ymir` door from the Ymir Codex plugin, so the block leaves it out. A server
  you defined yourself in `config.toml` under the same name is kept, and the block skips it.
- **Claude, project scope:** Ymir only changes Claude's user scope. A direct `engram` that remains in one
  project's local scope is named. Remove it from inside that project with `claude mcp remove --scope local engram`.

## If it does not work

- `seat --check` exits 1 → read the rows. Each one names the file and the servers that would change. Then run
  `seat`.
- A row says `fail ... does not parse` → that harness's config file is not valid JSON. The command left the file
  as it was. Fix the file and run `seat` again.
- Claude says `claude mcp refused` → run the printed `claude mcp add-json` by hand to see Claude's own error.

## Appended 2026-11-10 — two more Claude hooks: the Eindri ward and the global arm

Both are seated by `bin/seat/harness-extensions-install.sh` (user scope, like the AGENTS.md loader),
so they reach a Claude session in **any** project. Each is one named entry: install adds it if it is
missing, keeps a backup, and `--check` reports it stale until it is there. Nothing else in your
`~/.claude/settings.json` moves.

- **`.claude/hooks/eindri-only.sh`** — a `PreToolUse` hook on `Agent|Task`. It **denies** Claude's own
  subagents and tells the model the road instead: `bin/agents/eindri-start.sh` (or
  `bin/agents/agent-run.sh <figure> "<task>"`). A Claude worker is not a seat — no worktree, no
  Utgard, no Rune — so the house refuses it. The law is **Rule 49**,
  `RULES/49-workers-are-eindri.md`.
- **`.claude/hooks/ymir-arm.sh`** — a `Stop` hook (`asyncRewake`). It finds the house from pi's
  `~/.pi/agent/extensions/.ymir-root` rather than from the current project, so a Claude seat opened
  in any repository still takes a wake. Inside the Ymir repo itself it exits immediately; the repo's
  own `.claude/settings.json` arms that session.

An update seats both through migration `.agents/migrations/0021-the-claude-hooks.sh`; Gróa's update
re-verifies them and Eir's `claudehooks` surface fails when either is stale.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
