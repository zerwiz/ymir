#!/usr/bin/env python3
"""runtime-roots.py — the ward over every harness ROOT config Ymir writes (plan 248 P2, RULES/51).

A root agent loads the pinned runtime, never a working tree. This reads each root config a harness keeps in
the user's home and finds every path that lands inside a Ymir checkout which is NOT the runtime — the main
working tree, a Yggdrasil worktree, a second clone. `scan` names them; `repoint` moves each one onto the
runtime's twin of the same file (one backup per file kept) and HOLDS any path whose twin does not exist.

Called by bin/seat/runtime-root.sh (which resolves the runtime); not meant to be run by hand.

    runtime-roots.py scan    --runtime DIR --source pinned|checkout [--only HARNESS]
    runtime-roots.py repoint --runtime DIR --source pinned|checkout [--only HARNESS] [--dry-run]

A Ymir checkout is recognised by its own marks — `RULES/` beside `bin/seat/valknut-load.sh` — so a fork, a
second clone or a worktree is caught without a list of names. Nothing outside the named root configs is read.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import sys

HOME = os.path.expanduser("~")

# (harness, path under $HOME, kind). Kind decides how the file is read and written.
TARGETS = [
    ("pi", ".pi/agent/settings.json", "json"),
    ("pi", ".pi/agent/mcp-adapter.json", "json"),
    ("pi", ".pi/agent/mcp.json", "json"),
    ("pi", ".pi/agent/extensions/.ymir-root", "lines"),
    ("claude", ".claude.json", "claude-json"),
    ("claude", ".claude/settings.json", "json"),
    ("opencode", ".config/opencode/opencode.json", "json"),
    ("cursor", ".cursor/mcp.json", "json"),
    ("codex", ".codex/hooks.json", "json"),
    ("codex", ".codex/config.toml", "text"),
]

PATH_TOKEN = re.compile(r"(?:~|/)[^\s\"'`;|&<>()]+")


def real(p: str) -> str:
    try:
        return os.path.realpath(os.path.expanduser(p))
    except Exception:
        return p


_checkout_cache: dict[str, str] = {}


def checkout_of(path: str) -> str:
    """The Ymir checkout a path lies in, or '' — found by the checkout's own marks."""
    p = real(path)
    probe = p if os.path.isdir(p) else os.path.dirname(p)
    seen = []
    while probe and probe != "/":
        if probe in _checkout_cache:
            hit = _checkout_cache[probe]
            break
        seen.append(probe)
        if os.path.isdir(os.path.join(probe, "RULES")) and os.path.isfile(
                os.path.join(probe, "bin", "seat", "valknut-load.sh")):
            hit = probe
            break
        parent = os.path.dirname(probe)
        if parent == probe:      # "//" and friends are their own parent
            hit = ""
            break
        probe = parent
    else:
        hit = ""
    for s in seen:
        _checkout_cache[s] = hit
    return hit


class Finding:
    def __init__(self, harness: str, file: str, value: str, root: str, twin: str):
        self.harness, self.file, self.value, self.root, self.twin = harness, file, value, root, twin


def judge(value: str, runtime: str) -> tuple[str, str] | None:
    """(checkout, twin) when value names a path in a Ymir checkout that is not the runtime."""
    root = checkout_of(value)
    if not root or root == runtime:
        return None
    rp = real(value)
    rel = os.path.relpath(rp, root)
    twin = os.path.normpath(os.path.join(runtime, rel)) if rel != "." else runtime
    return root, twin


def tokens(s: str) -> list[str]:
    if not isinstance(s, str) or "/" not in s:
        return []
    s = re.sub(r"[a-zA-Z][a-zA-Z0-9+.-]*://\S*", " ", s)   # a URL is an address, never a checkout path
    if s.startswith("-") or s.startswith("+"):
        s = s[1:]
    if s.startswith("/") or s.startswith("~/"):
        if " " not in s:
            return [s]
    return PATH_TOKEN.findall(s)


def walk_json(node, out: list[str]):
    if isinstance(node, dict):
        for v in node.values():
            walk_json(v, out)
    elif isinstance(node, list):
        for v in node:
            walk_json(v, out)
    elif isinstance(node, str):
        out.extend(tokens(node))


def rewrite_json(node, swap):
    if isinstance(node, dict):
        return {k: rewrite_json(v, swap) for k, v in node.items()}
    if isinstance(node, list):
        return [rewrite_json(v, swap) for v in node]
    if isinstance(node, str):
        return swap(node)
    return node


def scope(kind: str, doc):
    """The part of a file that IS root config. ~/.claude.json also holds per-project state keyed by path
    (`projects`), which is not the root agent's config — only its user-scope mcpServers is."""
    if kind == "claude-json":
        return {"mcpServers": doc.get("mcpServers") or {}} if isinstance(doc, dict) else {}
    return doc


def dedupe_extensions(doc):
    if isinstance(doc, dict) and isinstance(doc.get("extensions"), list):
        kept = []
        for e in doc["extensions"]:
            if e not in kept:
                kept.append(e)
        doc["extensions"] = kept
    return doc


def stamp() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d-%H%M%S")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["scan", "repoint"])
    ap.add_argument("--runtime", required=True)
    ap.add_argument("--source", choices=["pinned", "checkout"], required=True)
    ap.add_argument("--only")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    runtime = real(a.runtime)

    rows: list[tuple[str, str, str, str]] = []
    bad = 0
    for harness, relpath, kind in TARGETS:
        if a.only and a.only != harness:
            continue
        path = os.path.join(HOME, relpath)
        if not os.path.isfile(path):
            continue
        short = "~/" + relpath
        try:
            text = open(path, encoding="utf-8").read()
        except Exception as exc:
            rows.append((harness, short, "skip", f"unreadable: {exc}"))
            continue

        doc = None
        values: list[str] = []
        if kind in ("json", "claude-json"):
            try:
                doc = json.loads(text) if text.strip() else {}
            except Exception:
                rows.append((harness, short, "skip", "does not parse — left untouched"))
                continue
            walk_json(scope(kind, doc), values)
        elif kind == "lines":
            values = [ln.strip() for ln in text.splitlines() if ln.strip()]
        else:
            values = tokens(text)

        found: dict[str, tuple[str, str]] = {}
        for v in values:
            j = judge(v, runtime)
            if j:
                found[v] = j
        if not found:
            rows.append((harness, short, "current", f"names no working tree (loads {runtime})"))
            continue

        if a.action == "scan":
            for v, (root, twin) in found.items():
                rows.append((harness, short, "working-tree", f"{v} is in {root}, not the runtime {runtime}"))
                bad += 1
            continue

        # repoint: swap each value for its twin when the twin exists; otherwise hold it.
        held = [v for v, (_r, t) in found.items() if not os.path.exists(t)]
        swaps = {v: t for v, (_r, t) in found.items() if os.path.exists(t)}

        def swap_str(s: str) -> str:
            if s in swaps:
                return swaps[s]
            for old, new in swaps.items():
                if old in s:
                    s = s.replace(old, new)
            return s

        if swaps and not a.dry_run:
            if kind in ("json", "claude-json"):
                if kind == "claude-json":
                    doc["mcpServers"] = rewrite_json(doc.get("mcpServers") or {}, swap_str)
                    new_doc = doc
                else:
                    new_doc = dedupe_extensions(rewrite_json(doc, swap_str))
                new_text = json.dumps(new_doc, indent=2, ensure_ascii=False) + "\n"
            elif kind == "lines":
                seen, out = set(), []
                lines = [runtime] if a.source == "pinned" else []
                for ln in lines + [swap_str(x) for x in values]:
                    if ln in seen:
                        continue
                    seen.add(ln)
                    out.append(ln)
                new_text = "\n".join(out) + "\n"
            else:
                new_text = swap_str(text)
            try:
                shutil.copy2(path, f"{path}.bak-runtime-{stamp()}")
                tmp = path + ".tmp-runtime"
                with open(tmp, "w", encoding="utf-8") as fh:
                    fh.write(new_text)
                shutil.copymode(path, tmp)
                os.replace(tmp, path)
            except Exception as exc:
                rows.append((harness, short, "fail", f"could not write: {exc}"))
                bad += 1
                continue
        verb = "would re-point" if a.dry_run else "re-pointed"
        for v, t in swaps.items():
            rows.append((harness, short, "repointed", f"{verb} {v} -> {t}"))
        for v in held:
            rows.append((harness, short, "held", f"{v} has no twin in the runtime {runtime} — re-point it by hand or "
                                                 f"land the change on the default branch and deploy the runtime"))
            bad += 1

    print(f"runtime_roots[{len(rows)}]{{harness,file,state,detail}}:")
    for r in rows:
        print("  " + ",".join(json.dumps(x, ensure_ascii=False) for x in r))
    if a.source == "checkout":
        print('runtime_roots_note[1]{note}:\n  "no runtime is pinned: the checkout serves every root agent '
              '(pin one in $YMIR_HOME/config/runtime.env)"')
    if bad and a.action == "scan":
        print("help: bin/seat/runtime-root.sh repoint   (or bin/seat/harness-extensions-install.sh — the same door, "
              "every harness)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
