## agents · 2026-10-22 — the web door is Exa, not a Wikipedia stub

**His words:** *"OMG NOOO REAL FUCKING ONLIEN RESACH: WE HAVE EXTENTIONS IN PI"* — and he was right.
The first cut of `bin/assistant/research.py` queried Wikipedia and called itself research. The house
already has real search: `pi-web-access` answers through **Exa's hosted MCP** endpoint, keyless.

```
correction[3]{was,is,law_kept}:
  "Wikipedia's API only","`POST https://mcp.exa.ai/mcp?tools=web_search_exa`, JSON-RPC `tools/call` — the same door the Allfather's own `web_search` tool uses. Wikipedia survives only as a labelled fallback when Exa cannot be reached","no key needed; an `exaApiKey` in `web-search.json`, if ever added, only raises the rate limit"
  "the source was a title","Exa returns `Title / URL / Published / body` per result; the URL is reduced to its **host** at the door and links, images and code are stripped from the text","a source is named, never linked — the gate's rule, applied before the text reaches the model"
  "one extract per answer","up to three sources, 900 characters each, 4,000 total","a research turn stays a short answer, not a page"
```

**The three laws did not move:** the model holds no callable; the query is the only thing taken from
the conversation (no URL from a message, so the door cannot be aimed); nothing fetched is ever
learned, written to the digest or mixed with private material; and the door is the Allfather's alone.

**Measured.** `research.py --query "OVK ventilation Boverket requirements"` → provider `exa`, three
sources, all `boverket.se`, in Swedish — the actual regulator. With the rail armed, asked
*"look up what an OVK inspection requires in Sweden"*:

> *"This information comes from the open web, specifically Boverket's regulations on mandatory
> ventilation control (OVK). An OVK inspection requires a certified inspector to verify that a
> building's ventilation system is functioning correctly and maintaining a satisfactory indoor
> climate."*

**Verified:** `walls-test` 25/25 (including *"the research door returns text, never a link"* and
*"research answers from the open web, never from the digest"*) · `adapter-test` 6/6 ·
`room-wall-test` 9/9.

**Files:** `bin/assistant/research.py` (rewritten on the Exa door), `bin/assistant/skirnir.py`,
`bin/assistant/walls-test.sh`, `docs/features/skirnir-the-assistant.md`.
