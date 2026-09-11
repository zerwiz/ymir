#!/usr/bin/env python3
"""kaia-status.py — Kaia memory bridge: health + store inspect.

Usage:
    kaia-status.py [--url http://127.0.0.1:4602]

Prints bridge health (store path, episode/fact/entity counts) and a store
summary from /inspect (recent episodes). Stdlib only.
"""
import argparse
import json
import os
import sys
import urllib.request

DEFAULT_URL = os.environ.get("KAIA_MEMORY_URL", "http://127.0.0.1:4602")


def get(url: str, path: str) -> dict:
    try:
        with urllib.request.urlopen(f"{url}{path}", timeout=3) as r:
            return json.load(r)
    except Exception as e:
        print(f"[kaia] bridge unreachable at {url}{path}: {e}", file=sys.stderr)
        sys.exit(1)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--url", default=DEFAULT_URL, help="bridge base url")
    args = ap.parse_args()

    health = get(args.url, "/health")
    print(f"bridge :  {args.url}  (health: {'ok' if health.get('ok') else 'DOWN'})")
    print(f"store  :  {health.get('db')}")
    print(f"episodes: {health.get('episodes')} · facts: {health.get('facts')} · "
          f"entities: {health.get('entities')} · edges: {health.get('edges')}")

    try:
        insp = get(args.url, "/inspect")
        print("\nrecent episodes:")
        for ep in (insp.get("recent_episodes") or insp.get("recent") or [])[:8]:
            content = str(ep.get("content", ep))[:160].replace("\n", " ")
            print(f"  - {content}")
    except SystemExit:
        pass  # /inspect shape varies; health is the contract
    return 0


if __name__ == "__main__":
    sys.exit(main())