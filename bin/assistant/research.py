#!/usr/bin/env python3
"""research.py — Skírnir's ONE window on the open web, and the smallest one that is useful.

    python3 research.py --query "OVK ventilation inspection" [--limit 3] [--lang en]

Why this is a separate door and not a tool the model holds (plan 101 §5, appended 2026-10-22):

  * The model never gets a callable. THIS process fetches; the model only reads what it returns as
    DATA, delimited, capped, and stripped of markup. An instruction inside a fetched page therefore
    cannot make anything happen — there is nothing to call.
  * It is KEYLESS and cannot be pointed at an arbitrary host. It queries Wikipedia's public API and
    nothing else: no URL from a message, no redirect following, no private address. That is what
    makes it safe to run inside a process that also talks to people.
  * What comes back is NOT knowledge. It is never written to the digest, never merged into an
    approved fact, and never mixed with private material — a research turn carries external text
    only, so the lethal trifecta (private data + untrusted content + outward speech) never closes.
  * A keyed provider may be added later as a SECOND function behind the same three rules. It is not
    here today because the vault holds no search key, and a door that pretends to have one would be
    a mock — the honest state is Wikipedia only.

Output is JSON on stdout so a caller never parses prose:

    {"query": "...", "sources": [{"title": "...", "domain": "en.wikipedia.org", "extract": "..."}]}
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request

UA = "Ymir-Skirnir/1.0 (+assistant research door; keyless; wikipedia only)"
MAX_EXTRACT = 900


def _get(url: str, timeout: int = 20) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        if resp.status != 200:
            raise RuntimeError(f"HTTP {resp.status}")
        return resp.read(2_000_000)


def _clean(text: str) -> str:
    """No markup, no links, no code — the gate's rules, applied at the DOOR as well as at the mouth."""
    text = re.sub(r"<[^>]{0,400}>", " ", text or "")
    text = re.sub(r"https?://\S+", "", text)
    text = re.sub(r"\[[^\]]{0,120}\]\([^)]{0,300}\)", "", text)
    text = text.replace("```", " ").replace("|", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text[:MAX_EXTRACT]


def wikipedia(query: str, limit: int, lang: str) -> list[dict]:
    api = f"https://{lang}.wikipedia.org/w/api.php"
    search = api + "?" + urllib.parse.urlencode({
        "action": "query", "list": "search", "srsearch": query,
        "format": "json", "srlimit": str(limit), "srprop": "snippet",
    })
    data = json.loads(_get(search).decode("utf-8", "replace"))
    hits = ((data.get("query") or {}).get("search") or [])[:limit]
    out: list[dict] = []
    for hit in hits:
        title = hit.get("title") or ""
        if not title:
            continue
        try:
            summary = json.loads(_get(
                f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/"
                + urllib.parse.quote(title.replace(" ", "_"))
            ).decode("utf-8", "replace"))
        except Exception:
            summary = {}
        extract = _clean(summary.get("extract") or hit.get("snippet") or "")
        if not extract:
            continue
        out.append({"title": title, "domain": f"{lang}.wikipedia.org", "extract": extract})
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--query", required=True)
    ap.add_argument("--limit", type=int, default=3)
    ap.add_argument("--lang", default=os.environ.get("SKIRNIR_RESEARCH_LANG", "en"))
    args = ap.parse_args()
    query = (args.query or "").strip()
    if not query:
        print(json.dumps({"query": "", "sources": [], "error": "empty query"}))
        return 2
    sources: list[dict] = []
    error = ""
    try:
        sources = wikipedia(query, max(1, min(args.limit, 5)), args.lang)
    except Exception as exc:                      # no network, no answer — never a guess
        error = f"{type(exc).__name__}: {exc}"[:200]
    print(json.dumps({"query": query, "sources": sources, "error": error}))
    return 0 if sources else 1


if __name__ == "__main__":
    sys.exit(main())
