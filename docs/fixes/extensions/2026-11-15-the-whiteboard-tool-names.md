# The board's tools are named for the board, and the old names answer once

**Date:** 2026-11-15 · **Component:** extensions · **Doors:** `.pi/extensions/excalidraw/index.ts`, `bin/mcp/ymir-mcp.py` · **Plan:** 284 (§21 step 5)

## What was wrong

The two tools an agent calls to read the whiteboard's tickets and its three services were registered as
`excalidraw_tickets` and `excalidraw_servers`. The board stopped being that product on 2026-11-15: the name a
person reads says *whiteboard*, the promo surfaces are gone, and the surface is served from our own repository
(`zerwiz/gimle-whiteboard`). An agent-facing name that still says otherwise is the last stale sign on the door.

There was also a small correctness gain. Both registrations were bare `pi.registerTool({…})` object literals, so a
second name for the same behaviour meant a second copy of the handler — two places to fix, guaranteed to drift.
They are now one object each, registered twice.

## What changed

| Before | After |
|---|---|
| `excalidraw_tickets` | `whiteboard_tickets` — reads the tickets at `<EXCALIDRAW_ROOT>/tickets` |
| `excalidraw_servers` | `whiteboard_servers` — status/start/stop for board, bridge, collab |

Each is now:

```ts
const ticketsTool = { name: "whiteboard_tickets", /* … */ };
pi.registerTool(ticketsTool);
// Kept for one release: the old name answers, delegating to the same object.
pi.registerTool({
  ...ticketsTool,
  name: "excalidraw_tickets",
  description: "Deprecated alias for whiteboard_tickets — … one release. " + ticketsTool.description,
});
```

**The old names answer for one release.** A prompt, a skill or a script that still says `excalidraw_tickets`
works exactly as before, and its description now says it is deprecated and names its replacement — so the next
reader moves without a search.

Deliberately unchanged: `excalidraw_diagram` and `excalidraw_app`, which name a file format and an editor shell
rather than the product, and the `.excalidraw` extension, which boards already saved depend on.

## How it was proved

- The extension loads: extracted from the tree with its three sibling modules and imported under
  `node --experimental-strip-types` — `LOADED ok, default export: function`.
- Both names are registered: the file carries two `whiteboard_*` registrations and two alias registrations.
- The MCP proxy's own list (`bin/mcp/ymir-mcp.py`) and the harness asset
  (`.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`) name the new tools and record the
  old ones as aliases.

## What is owed

- After one release, delete the two alias registrations and the note in `bin/mcp/ymir-mcp.py`.

## Where this sits

`docs/fixes/extensions/` is the extension surface's history; the naming law is plan 284 §21, and the board's own
repository is `zerwiz/gimle-whiteboard` pinned by tag in the Gimlé kit.

## CHANGE LOG

- 2026-11-15 — review-mend: added missing heading for #776
