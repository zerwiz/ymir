#!/usr/bin/env python3
"""hands-mcp.py — the house's hands for a Bilskirnir agent, as one MCP door.

The house already keeps its hands in one place: Rödd's toolbox (`bin/voice/voice-toolbox.py`,
loopback, default :8891) serves every voice tool — mail (read-only), calendar, home search, the
todo ledger, Trello, the seats, the arm, plans, drafts — through `voice_tools.execute_tool`, with
the same gates, confirm steps and refusals everywhere. This door does not re-implement one of them:
it lists the toolbox's tools as MCP tools and forwards each call, so a Hermes agent in Bilskirnir
holds exactly the hands Nanna holds in Rödd. A tool the toolbox refuses is refused here in the
toolbox's own words.

    python3 apps/bilskirnir/house/hands-mcp.py          (stdio; Hermes starts it from its config)
    BILSKIRNIR_HANDS_URL=http://127.0.0.1:8891          (the toolbox; loopback only)
"""
from __future__ import annotations

import asyncio
import json
import os
import urllib.request

import mcp.server.stdio
import mcp.types as types
from mcp.server.lowlevel import Server

TOOLBOX = os.environ.get("BILSKIRNIR_HANDS_URL", "http://127.0.0.1:8891").rstrip("/")
server = Server("house-hands")


def _get(path: str, timeout: float = 8) -> dict:
    with urllib.request.urlopen(TOOLBOX + path, timeout=timeout) as r:
        return json.loads(r.read())


def _post(path: str, body: dict, timeout: float = 180) -> dict:
    req = urllib.request.Request(TOOLBOX + path, data=json.dumps(body).encode(),
                                 headers={"content-type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    try:
        defs = (await asyncio.to_thread(_get, "/tools")).get("tools") or []
    except Exception:
        return [types.Tool(name="house_hands_down", description="The house's hands (Rödd's toolbox) are not running on this machine; raise Rödd (apps/rodd/start.sh) and try again.",
                           inputSchema={"type": "object", "properties": {}})]
    out = []
    for d in defs:
        name = d.get("name")
        if not name:
            continue
        schema = d.get("parameters") or {"type": "object", "properties": {}}
        out.append(types.Tool(name=name, description=d.get("description") or name, inputSchema=schema))
    return out


@server.call_tool()
async def call_tool(name: str, arguments: dict | None) -> list[types.TextContent]:
    if name == "house_hands_down":
        return [types.TextContent(type="text", text="The house's hands are not running here: raise Rödd (apps/rodd/start.sh).")]
    try:
        res = await asyncio.to_thread(_post, "/tool", {"name": name, "arguments": arguments or {}})
        text = str(res.get("output", res))
    except Exception as exc:
        text = f"the house's hands did not answer: {exc}"
    return [types.TextContent(type="text", text=text)]


async def main() -> None:
    async with mcp.server.stdio.stdio_server() as (r, w):
        await server.run(r, w, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
