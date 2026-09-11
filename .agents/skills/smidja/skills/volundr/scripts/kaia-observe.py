#!/usr/bin/env python3
"""kaia-observe.py — write a lesson/episode into Kaia's engram memory.

Usage:
    kaia-observe.py "<content>" [--tags a,b,c] [--actors x,y] [--salience 0.7] \
                   [--url http://127.0.0.1:4602]

POST /observe on the memory bridge. On success prints the new episode id.
This is the same write path `factory learn <factory_id>` and `factory teach <project>`
use — use it when YOU (as orchestrator) want to record a lesson directly.
"""
import argparse
import json
import os
import sys
import urllib.request

DEFAULT_URL = os.environ.get("KAIA_MEMORY_URL", "http://127.0.0.1:4602")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("content", help="the episode content (the lesson / outcome)")
    ap.add_argument("--tags", default="learn", help="comma-separated tags")
    ap.add_argument("--actors", default="", help="comma-separated actors")
    ap.add_argument("--salience", type=float, default=0.7,
                    help="importance 0..1 (default 0.7, learn salience)")
    ap.add_argument("--url", default=DEFAULT_URL, help="bridge base url")
    args = ap.parse_args()

    body = json.dumps({
        "content": args.content,
        "tags": [t.strip() for t in args.tags.split(",") if t.strip()],
        "actors": [a.strip() for a in args.actors.split(",") if a.strip()] or None,
        "salience": args.salience,
    }).encode()

    req = urllib.request.Request(f"{args.url}/observe", data=body,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            resp = json.load(r)
    except Exception as e:
        print(f"[kaia] observe failed ({args.url}/observe): {e}", file=sys.stderr)
        return 1

    print(f"observed episode id: {resp.get('id')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())