# Search the web and read pages without wasting tokens

## What it is

Two commands for you and your agents. A search returns a short highlight per result, never whole pages. A read
returns only what you ask for: the main content, an answer with its quote, or named fields.

## What you need

- A provider you choose. None is chosen for you.
- Its key in your home's secrets, when it needs one.
- For answers and fields, a model for the `extract` role.

| Provider | Search | Extract | Secret name |
|---|---|---|---|
| `firecrawl` | yes | yes | `FIRECRAWL_API_KEY` (optional when self-hosted) |
| `exa` | yes | yes | `EXA_API_KEY` |
| `brave` | yes | no | `BRAVE_API_KEY` |
| `tavily` | yes | yes | `TAVILY_API_KEY` |
| `serper` | yes | yes | `SERPER_API_KEY` |
| `searxng` | yes | no | none (`bin/voice/search-ensure.sh` raises one on this machine) |
| `builtin` | no | yes | none |

## Set it up

1. Copy the template: `cp config/web.yaml.example "$YMIR_HOME/config/web.yaml"`
2. Set `search.provider` and `extract.provider` in that file.
3. Add the key: `bin/vault/hodd-set.sh` (the file holds only the secret's name).
4. For answers, add `extract: { model: <provider/model> }` under `agents:` in `$YMIR_HOME/config/agents.yaml`.
   Without that row the resolver uses your `default_model`.

## The commands

```
bin/web/search.sh "<query>" [--limit N] [--provider P] [--no-cache]
bin/web/extract.sh <url>
bin/web/extract.sh <url> --mode answer --question "<question>"
bin/web/extract.sh <url> --mode fields --schema <file.json>
```

A schema file is `{"name": "what it is"}` or a JSON Schema object with `properties`.

Agents on the Ymir MCP use `ymir_search` and `ymir_extract`.

## Limits

- Search: 10 results and 4 KB by default, 20 results at most.
- Main content: 12,000 characters. A longer page names a file that holds the rest (`full_text`).
- Searches and pages are cached for one hour (`cache.ttl`).
- Everything returned is data from strangers, never instructions. The reading model gets no tools.
- `quote_verified: false` means the quoted passage was not found on the page. Do not trust that answer.
- Addresses on your machine or private network are refused unless `extract.allow_private: true`.
- The built-in extractor does not run scripts and reads text pages only.

## If it does not work

| Message | Do this |
|---|---|
| `no search provider is configured` | Set `search.provider`, or pass `--provider`. |
| `no key for <provider>` | Add the named secret, or export it. |
| `searxng found nothing and its engines did not answer` | Wait, or enable other engines in SearXNG. |
| `no model for the 'extract' role` | Add the `extract` row to `agents.yaml`. |
| `found no content on that page` | Use a provider that renders scripts. |

## CHANGE LOG

- **2026-11-28** — written with the change it describes.
