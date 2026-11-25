# Huginn's web tools — search, read and browse

## What it is

Huginn is the raven who flies out and brings back what he sees. His three tools reach the web:

| Tool | What it does | Where it runs |
|---|---|---|
| Firecrawl | Searches the web, reads a page as markdown, maps and crawls a site | A compose stack, project `firecrawl`, on `127.0.0.1:3002` |
| SearXNG | The search engine Firecrawl searches through | One container, `ymir-searxng`, on `127.0.0.1:8899` |
| Browser | Opens a page in a real (headless) browser, clicks, types, takes a screenshot | Playwright MCP on `chrome-headless-shell`, started by your harness when needed |

Install and every update seat the browser door and the Firecrawl door in Claude Code, pi, OpenCode, Hermes, Codex and Cursor. The browser keeps its profile in memory, so your own browser, its logins and its tabs are never touched. It speaks over stdio and opens no port.

## What you need

- Docker, and a Firecrawl checkout (`~/firecrawl` by default) with an override file that gives each container `restart: unless-stopped` and the label `ymir.owner`.
- For the browser: Playwright's headless shell. If it is missing, run `npx playwright install chromium-headless-shell`.
- Node, for `npx`.

## The commands

Ask what is up, where, and on which road (local, or borrowed from another machine):

```bash
bin/fleet/huginn-web.sh status
```

Raise the Firecrawl stack, join SearXNG to it, wait for port 3002 and prove one search:

```bash
bin/fleet/huginn-web.sh up
```

Lower it (the data volumes stay):

```bash
bin/fleet/huginn-web.sh down
```

From a harness, the same three are the tool `ymir_huginn` with the action `status`, `up` or `down`.

## Where the addresses live

Nothing is hard-coded. Set these in the environment, or as `KEY=value` lines in `$YMIR_HOME/config/huginn.env`:

| Key | Default | Meaning |
|---|---|---|
| `YMIR_FIRECRAWL_URL` | `http://127.0.0.1:3002` | Where Firecrawl answers; the seat writer puts it in the Firecrawl door |
| `YMIR_FIRECRAWL_BORROW_URL` | none | Another machine's Firecrawl to use when the local one is down |
| `YMIR_FIRECRAWL_DIR` | `~/firecrawl` | The stack's main checkout |
| `YMIR_SEARXNG_CONTAINER` | `ymir-searxng` | The SearXNG container |
| `YMIR_SEARXNG_URL` | `http://127.0.0.1:8899` | Where SearXNG answers |
| `YMIR_PLAYWRIGHT_SHELL` | found at run time | The `chrome-headless-shell` binary |
| `YMIR_PLAYWRIGHT_MCP_VERSION` | pinned in the launcher | The exact `@playwright/mcp` version |

A seat with no stack and no borrow address reports Firecrawl as `down` with road `none` and names the command to run.

## Limits

- `up` raises the stack only from its main checkout, never from a worktree or a scratch folder, and never a second copy when one already answers.
- A cold start races RabbitMQ's health check, so `up` tries up to three times; the first full start after a `down` takes about a minute and a half.
- `up` builds nothing. If the images are missing it says so and, with under 50 GiB free on `/`, refuses to build.
- SearXNG leaves the stack's network when it is recreated; `up` joins it again every time.

## If it does not work

- `status` shows Firecrawl `down`: run `bin/fleet/huginn-web.sh up`.
- `status` shows the browser `missing`: run `npx playwright install chromium-headless-shell`.
- `eir-doctor.sh check` has two rows for this, `browser` and `huginn`. `eir-doctor.sh fix browser huginn` re-seats the doors and raises the stack.

## CHANGE LOG

- 2026-11-25 — page opened with plan 373: the browser door and Huginn's status, up and down.
