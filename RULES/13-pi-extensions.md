# Rule 13 — Pi extensions: one home, pi's own layout, and a gate that proves it

> Adopted 2026-10-04, after an investigation that found the extension tree's source split across
> two directories, the running harness three days stale, and the document that governs it
> answering "where does an extension live?" two incompatible ways.

**Built on [pi.dev/docs/latest/extensions](https://pi.dev/docs/latest/extensions) and on the
installed loader's own rule.** Where this rule and habit disagree, pi's source wins.

## What pi actually does — the three facts the rule rests on

1. **An extension is a file or a directory with an entry point.** Pi loads direct `.ts`/`.js`
   files, and a **subdirectory only if it holds `index.ts` or `index.js`** (or a `package.json`
   with a `pi` field). From the installed loader: *"No recursion beyond one level."*
   **A helper directory named `lib/` is therefore never scanned — and that is correct.**
2. **Two auto-discovered locations exist**: `~/.pi/agent/extensions/` (global) and
   `.pi/extensions/` (project). **Pi does not de-duplicate.** An extension in both registers its
   tools twice, pi exits with `Tool "<name>" conflicts with …`, and **no agent can be seated.**
   The symptom is remote — herdr reports "the pane must sit at an interactive shell prompt".
3. **A deploy is a copy, and nothing re-runs it.** A repo edit changes nothing in the running
   harness until something deploys it again.

## The law

1. **One home per extension, ever.** The source is `.pi/shared/extensions/`; the deployed copy
   is `~/.pi/agent/extensions/`, written by `bin/valknut-load.sh --pi`. **Never the same
   extension in both, and never in two of the three trees.**
2. **`.pi/extensions/` registers nothing.** It holds no-op factories that exist solely to stop a
   duplicate collision, and nothing else. **A file there that grows past a no-op is a bug**, and
   `--check` fails on it.
3. **A multi-file extension is a directory with an `index.ts`.** A single-file extension is a
   single file. **An extension's own internals live inside its own directory** — Ró's helpers
   belong to Ró, Skuld's to Skuld. **A shared `lib/` is only for what genuinely has no owner**,
   and every entry in it states why.
4. **No thin loaders.** A project-local file that imports a shared factory and calls it with
   `pi` registers the same tools a second time, from a directory pi already scanned. **You
   cannot both deploy a copy and load the source.** Pick one; we deploy.
5. **Take `pi` as `any`.** `@earendil-works/pi-coding-agent` is **not installed as a package**
   here, so an extension that imports its types cannot load at all. Declare tool `parameters` as
   a plain JSON schema object.
6. **Start nothing in the factory.** Per pi's docs: do not start processes, sockets, watchers or
   timers in the factory — some invocations load extensions without starting a session. Begin
   at `session_start`; release at `session_shutdown`, idempotently, because reload, session
   replacement and process exit all converge on that path.
7. **Load order is a contract.** *"Handlers run in extension load and registration order."* A
   restructure that changes the tree must prove Sýn's `before_agent_start`, Gná's
   `session_start` and Skuld's supervision still seat.
8. **Deploy both the extension and everything it imports.** Copying the top-level files without
   their modules ships extensions that **cannot load** — the exact failure that made
   `Cannot find module ./lib/…` the first symptom anyone saw.
9. **The gate is `bin/valknut-load.sh --check`, and it must pass.** Deployed tree byte-identical
   to source; helper modules deployed; no test file in the live tree; nothing in two load paths.
   **A gate that only ever passes is worse than no gate**, so every check is proved by breaking
   the thing it watches.

## Why, in one sentence

**Nothing in the extension tree is wrong in a way that throws — it is wrong in a way that lists
cleanly**, which is why a stale deploy, a half-finished migration and two contradictory
descriptions all survived until somebody went looking.

## The failures this rule exists to prevent

| | measured 2026-10-04 |
|---|---|
| **a stale deploy, invisible** | deployed `ymir-subagents.ts` was **12,991 B against a 13,748 B source**. The missing lines are `bin/erindi-brief.sh` — the fix that stops a dispatch seating a figure with an unfilled brief. Every file listing looked correct |
| **an unfinished migration** | plan 29 built a flat `.pi/extensions/` + `lib/`. Plan 58 moved the extensions to `.pi/shared/extensions/` and **did not move their internals**, so the loader grew a second copy line. One system, two sources, and the second was never planned |
| **a specified-but-unbuildable half** | plan 58 says `.pi/extensions/*.ts` should be "thin loaders that pull the shared set". That is mutually exclusive with a copy deploy, so they became no-ops. **The next reader reads that row as an outstanding task** |
| **the doc answering twice** | one table said `.pi/extensions/` held the governance four; a later section said *"never in `.pi/extensions/`"*. Neither was true |
| **a collision that seats nobody** | two load paths register the same tool twice and pi exits. The only symptom herdr can report is that the pane will not sit at a prompt |

## Not this rule's business

**`~/.pi/agent/agents/` and `.agents/agents/` are governed by Rule 02** (agents, not
extensions). **MCP servers** are `pi.registerMcpServer()` or `mcp.json`, not extensions. **The
other harnesses** — OpenCode, Claude Code, Codex, Cursor — have their own adapters and their own
governed asset; this rule is about the **Pi** extension surface only.
