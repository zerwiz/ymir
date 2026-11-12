#!/usr/bin/env python3
"""ymir-mcp.py (seat copy) — a thin pointer, kept because files are moved, never deleted (Rule 11).

The live MCP face is `bin/mcp/ymir-mcp.py`; every installed config names it. This path once held a
second copy of the face (and, for a while, its own todo logic). It now only hands over to the live
face, so there is ONE implementation and ONE writer of the task board (`bin/records/todos.sh`).
"""
import os
import sys

live = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mcp", "ymir-mcp.py")
os.execv(sys.executable, [sys.executable, live, *sys.argv[1:]])
