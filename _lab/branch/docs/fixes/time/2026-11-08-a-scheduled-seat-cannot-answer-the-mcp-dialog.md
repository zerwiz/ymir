# A scheduled seat cannot answer the MCP trust dialog, and herdr drops agent args

**2026-11-08 · component: time**

## The two faults, measured by watching a real pane

1. **An interactive pi in a scheduled pane stops on a question.** The pi-mcp-adapter asks a human —
   *"Allow project MCP server 'engram'?"* — and a job that runs at 03:41 has nobody to answer it. The
   pane stood on that dialog three times while the Allfather watched. The adapter's own source is
   explicit: the grant lives in the **user-global** MCP config (`settings.projectServers: "allow"`), and
   a project config may not grant itself — so an updater must not depend on it at all.
2. **`herdr agent start <name> … -- <agent-args>` does not forward the args.** The pane came up as a
   plain `pi` with the default model and no `--no-mcp`, whatever was passed after `--`.

## What was fixed

The seat now runs a **launcher script** — the flags cannot be dropped because the pane is told one word,
`bash <runner>` — and that runner uses **print mode**:

```
pi -p --model <resolved from the home> --append-system-prompt <brief> --no-mcp --mcp-project-servers deny -t bash,read "<order>"
```

Print mode declares the project servers blocked, says so once, and answers the order. That is a real pi
agent in the pane; it simply does not draw the TUI, which is the only shape a scheduled seat can use.

## Verified — the agent's own line, from the pane

```
groa: check-only · 1096dd06 → 6fbb38bf · branch yggdrasil/areas-of-a-project, not main, with 12 dirty
INDEX and asset paths — nothing moved
```

An agent read this machine's facts, refused to move a feature branch, counted the dirty paths, and forced
nothing.

## CHANGE LOG

- **2026-11-08** — Opened with both faults and the print-mode seat.
