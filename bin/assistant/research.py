#!/usr/bin/env python3
"""research.py — Skírnir's window on the open web: the SAME provider Pi's web tool uses.

    python3 research.py --query "OVK ventilation Boverket requirements" [--limit 3]

The house already pays for real search — `pi-web-access` answers through Exa's hosted MCP endpoint,
keyless, and that is the door this script knocks on. Nothing is invented here and nothing is scraped
from a stub: it is the same search the Allfather's own `web_search` tool performs.

WHY THIS IS A SEPARATE PROCESS, AND NOT A TOOL IN THE MODEL (plan 101 §5, appended 2026-10-22):

  * The model holds NO callable. This process searches; the model reads the returned text as DATA,
    delimited and capped. An instruction inside a fetched page has nothing to invoke.
  * The query is the only thing that comes from the conversation. No URL is ever taken from a
    message, so a stranger cannot aim the door at a host of their choosing.
  * What comes back is NOT knowledge: it is never written to the digest, never merged into an
    approved fact, never learned. A research turn therefore never holds private data, untrusted
    content and outward speech at the same time — the lethal trifecta stays open.
  * The door strips links from the text it returns, because the gate forbids them and a quotation
    must not smuggle one through.

Exa's MCP returns one text block per result in the shape `Title: … / URL: … / Published: … / body`.
The URL is reduced to its HOST before it leaves this process: a source is named, never linked.

Output is JSON on stdout:

    {"query": "...", "provider": "exa", "sources": [{"title": "...", "domain": "...", "extract": "..."}]}
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

EXA_MCP_URL = "https://mcp.exa.ai/mcp"
EXA_TOOL = "web_search_exa"
UA = "Ymir-Skirnir/1.0 (assistant research door; exa mcp; text only)"
MAX_EXTRACT = 900
MAX_TOTAL = 4000


def _config_key() -> str:
    """An Exa key raises the rate limit. The extension's own store is the only place it can live."""
    for path in (os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "pi", "web-search.json"),
                 os.path.expanduser("~/.pi/web-search.json")):
        try:
            with open(path) as fh:
                key = (json.load(fh) or {}).get("exaApiKey")
            if isinstance(key, str) and key.strip():
                return key.strip()
        except Exception:
            continue
    return os.environ.get("EXA_API_KEY", "").strip()


def _clean(text: str) -> str:
    """Text only: no tags, no links, no images, no code fences — the gate's rules, at the door."""
    text = re.sub(r"<[^>]{0,400}>", " ", text or "")
    text = re.sub(r"!\[[^\]]{0,200}\]\([^)]{0,300}\)", " ", text)
    text = re.sub(r"\[([^\]]{0,200})\]\([^)]{0,300}\)", r"\1", text)
    text = re.sub(r"https?://\S+", "", text)
    text = text.replace("```", " ").replace("|", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text[:MAX_EXTRACT]


def _host(url: str) -> str:
    m = re.match(r"https?://([^/]+)", url or "")
    return (m.group(1) if m else "").lower().lstrip("www.")


def exa(query: str, limit: int) -> list[dict]:
    body = json.dumps({
        "jsonrpc": "2.0", "id": 1, "method": "tools/call",
        "params": {"name": EXA_TOOL, "arguments": {"query": query, "numResults": limit}},
    }).encode()
    headers = {"Content-Type": "application/json",
               "Accept": "application/json, text/event-stream",
               "User-Agent": UA, "x-exa-source": "pi-web-access"}
    key = _config_key()
    if key:
        headers["x-api-key"] = key
    req = urllib.request.Request(f"{EXA_MCP_URL}?tools={EXA_TOOL}", data=body, headers=headers)
    with urllib.request.urlopen(req, timeout=45) as resp:
        raw = resp.read(4_000_000).decode("utf-8", "replace")

    payload = None
    for line in raw.splitlines():
        if line.startswith("data:"):
            try:
                payload = json.loads(line[5:].strip())
                break
            except Exception:
                continue
    if payload is None:
        try:
            payload = json.loads(raw)
        except Exception:
            return []
    result = (payload.get("result") or {})
    if result.get("isError"):
        return []
    text = "".join(part.get("text", "") for part in (result.get("content") or [])
                   if isinstance(part, dict))

    sources: list[dict] = []
    blocks = re.split(r"(?=^Title: )", text, flags=re.M)
    for block in blocks:
        m = re.match(r"Title:\s*(.+?)\s*$", block, re.M)
        if not m:
            continue
        title = m.group(1).strip()
        u = re.search(r"^URL:\s*(\S+)\s*$", block, re.M)
        body_text = re.sub(r"^(Title|URL|Published|Author|Highlights):.*$", "", block, flags=re.M)
        extract = _clean(body_text)
        if not extract:
            continue
        sources.append({"title": title, "domain": _host(u.group(1) if u else ""), "extract": extract})
        if len(sources) >= limit:
            break
    return sources


def wikipedia(query: str, limit: int, lang: str = "en") -> list[dict]:
    """The fallback when Exa cannot be reached: public, keyless, and honest about being a fallback."""
    import urllib.parse
    api = f"https://{lang}.wikipedia.org/w/api.php"
    url = api + "?" + urllib.parse.urlencode({
        "action": "query", "list": "search", "srsearch": query, "format": "json",
        "srlimit": str(limit), "srprop": "snippet"})
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.loads(resp.read(2_000_000).decode("utf-8", "replace"))
    out = []
    for hit in ((data.get("query") or {}).get("search") or [])[:limit]:
        extract = _clean(hit.get("snippet") or "")
        if extract and hit.get("title"):
            out.append({"title": hit["title"], "domain": f"{lang}.wikipedia.org", "extract": extract})
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--query", required=True)
    ap.add_argument("--limit", type=int, default=3)
    ap.add_argument("--no-fallback", action="store_true")
    args = ap.parse_args()
    query = (args.query or "").strip()
    limit = max(1, min(args.limit, 5))
    if not query:
        print(json.dumps({"query": "", "provider": "", "sources": [], "error": "empty query"}))
        return 2

    provider, sources, error = "exa", [], ""
    try:
        sources = exa(query, limit)
    except urllib.error.HTTPError as exc:
        error = f"exa HTTP {exc.code}"
    except Exception as exc:
        error = f"exa {type(exc).__name__}: {exc}"[:160]
    if not sources and not args.no_fallback:
        try:
            sources = wikipedia(query, limit)
            provider = "wikipedia-fallback" if sources else provider
        except Exception as exc:
            error = (error + " | " if error else "") + f"wikipedia {type(exc).__name__}: {exc}"[:120]

    total = 0
    for src in sources:
        src["extract"] = src["extract"][:max(0, MAX_TOTAL - total)]
        total += len(src["extract"])
    print(json.dumps({"query": query, "provider": provider, "sources": sources, "error": error}))
    return 0 if sources else 1


if __name__ == "__main__":
    sys.exit(main())
