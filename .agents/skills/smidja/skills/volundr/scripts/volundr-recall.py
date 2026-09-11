#!/usr/bin/env python3
"""volundr-recall.py — recall what Völundr remembers about a project.

Usage:
    volundr-recall.py <project> [k] [mode] [--url http://127.0.0.1:4602]

k     : number of hits (default 5)
mode  : hybrid | cosine | spreading (default hybrid)

Prints `- [score] content` bullets, same shape the orchestrator gets injected
before dispatch. Returns exit 0 even on empty recall (no memory yet = fine).
"""
import argparse
import json
import os
import sys
import urllib.parse
import urllib.request

DEFAULT_URL = os.environ.get("KAIA_MEMORY_URL", "http://127.0.0.1:4602")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("project", help="project name / repo basename to recall")
    ap.add_argument("k", nargs="?", type=int, default=5, help="number of hits")
    ap.add_argument("mode", nargs="?", default="hybrid",
                    choices=["hybrid", "cosine", "spreading"])
    ap.add_argument("--url", default=DEFAULT_URL, help="bridge base url")
    args = ap.parse_args()

    q = urllib.parse.quote(args.project)
    url = f"{args.url}/recall?q={q}&k={args.k}&mode={args.mode}"
    try:
        with urllib.request.urlopen(url, timeout=5) as r:
            data = json.load(r)
    except Exception as e:
        print(f"[kaia] recall failed ({url}): {e}", file=sys.stderr)
        return 1

    results = data.get("results", [])
    if not results:
        print(f"(no prior memory for '{args.project}' yet — first run)")
        return 0

    for hit in results:
        content = str(hit.get("episode", {}).get("content", hit))[:300]
        score = hit.get("score", 0.0)
        print(f"- [{score:.2f}] {content}")
    return 0


if __name__ == "__main__":
    sys.exit(main())