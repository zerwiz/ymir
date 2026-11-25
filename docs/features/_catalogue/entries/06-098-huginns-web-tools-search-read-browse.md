---
section: agents-work-collaboration
---
| Agents | **Huginn's web tools — Firecrawl, SearXNG and the browser** (`bin/fleet/huginn-web.sh`, MCP `ymir_huginn`, `bin/seat/playwright-mcp-launch.sh`) | Search the web, read a page as markdown and drive a headless browser from every harness. `status` says for each tool whether it is up, where, and whether the road is local or borrowed; `up` raises the Firecrawl stack from its main checkout, joins SearXNG and proves one search; `down` lowers it. The browser is Playwright MCP on `chrome-headless-shell` with an in-memory profile and no listening port. Eir has a `browser` and a `huginn` row. | [docs/features/huginns-web-tools.md](docs/features/huginns-web-tools.md) |
