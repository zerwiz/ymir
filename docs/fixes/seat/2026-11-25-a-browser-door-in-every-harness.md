# A browser door in every harness

**Component:** seat (plan 373, items 1 and 5)

## What was missing

Ymir's MCP had no browser tools, so each agent that needed to look at a page wrote its own Playwright script, each with its own browser, size and way of waiting.

## What changed

- `bin/seat/playwright-mcp-launch.sh` runs Microsoft's `@playwright/mcp`, pinned to an exact version (0.0.86), on Playwright's `chrome-headless-shell`. The shell is found at run time (`YMIR_PLAYWRIGHT_SHELL`, then `PLAYWRIGHT_BROWSERS_PATH`, newest revision first). The profile is in memory (`--isolated`), and the server speaks stdio, so it opens no port. A missing shell refuses and names `npx playwright install chromium-headless-shell`.
- `bin/bridge/mcp-config-seat.py` adds the `playwright` door to the one set that Claude Code, pi, OpenCode, Cursor, Codex and Hermes are seated from, so install and every update carry it.
- Eir has a new `browser` surface (registered in `config/surfaces.yaml`). It is red when the door is not seated for Claude, when the shell is missing, when the seated path does not exist, or when the door does not answer an MCP initialize within 40 seconds.

## Proof

A Claude session opened in the home folder, not the checkout, opened `https://ymir.zerwiz.org/`, took a screenshot, resized to 390x844 and then 1280x800, and read the title "Ymir — an AI runtime built on the bones of giants".
