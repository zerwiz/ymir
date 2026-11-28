## runtime · unversioned · 2026-11-28 — web search and extraction that save tokens

### Why

Reading the web cost whole pages. The house had search and clean extraction only through one provider's MCP server
or the voice's own SearXNG call, so a harness without that server pasted navigation, banners and footers into its
context.

### What changed

- `bin/web/search.sh` returns ranked results as JSON lines (title, URL, a highlight of at most 300 characters),
  capped at 10 results and 4 KB, cached per query under `$XDG_CACHE_HOME/ymir/search`.
- `bin/web/extract.sh` returns capped main content, an answer with its quoted passage, or named fields. The last two
  use the model of the `extract` role (`bin/model/agent-model.sh extract`), started with no tools.
- Providers come from `$YMIR_HOME/config/web.yaml` (template `config/web.yaml.example`). None is a default. Keys are
  named there and read from the environment or `bin/vault/hodd.sh emit`.
- The Ymir MCP serves both as `ymir_search` and `ymir_extract`.
- Every output is labelled as data, never instructions. `extract` refuses private addresses unless the config allows
  them, and a provider call never follows a redirect with its key.

### Limits

- The private-address check resolves the host before the request, so a name that changes its answer between the check
  and the read (DNS rebinding) is not caught.
- The built-in extractor does not run a page's scripts and reads text pages only.

### Files

- `bin/web/web.py`
- `bin/web/search.sh`
- `bin/web/extract.sh`
- `bin/web/tests/test_web.py`
- `bin/gates/checks.d/0445-web-search.sh`
- `bin/mcp/ymir-mcp.py`
- `bin/mcp/doors.yaml`
- `config/web.yaml.example`
- `.agents/config/agents.yaml.example`
- `docs/features/web-search-and-extraction.md`

### Test

`python3 bin/web/tests/test_web.py` — providers mocked, the SearXNG path and the extractor against a loopback fake.
