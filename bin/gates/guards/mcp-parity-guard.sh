#!/usr/bin/env bash
# mcp-parity-guard.sh — every door in bin/mcp/doors.yaml has its MCP tool (plan 358, 2026-11-22).
#
# A harness reaches Ymir through the MCP, so a door built without its tool is closed to every harness but pi. The
# register `bin/mcp/doors.yaml` lists each door that MUST have a tool. This ward fails when a row names a tool that
# `bin/mcp/ymir-mcp.py` does not register (read from the source, so it needs no MCP SDK), or a door file that is not in
# the tree. A row with `when:` is waiting for its build: it is judged only once its door file exists.
#
#   bin/gates/guards/mcp-parity-guard.sh              judge this tree
#   bin/gates/guards/mcp-parity-guard.sh --repo DIR   judge another tree
# Exit: 0 every door has its tool · 1 a door is missing its tool.
set -uo pipefail
HERE="${BASH_SOURCE[0]%/*}"
ROOT="$(readlink -f "$HERE/../../..")"
[ "${1:-}" = "--repo" ] && ROOT="$2"
exec python3 - "$ROOT" <<'PY'
import ast, re, sys
from pathlib import Path
root = Path(sys.argv[1])
reg, srv = root / "bin/mcp/doors.yaml", root / "bin/mcp/ymir-mcp.py"
if not reg.is_file() or not srv.is_file():
    print(f"mcp-parity-guard[1]{{finding}}:\n  \"{'no register' if not reg.is_file() else 'no server'} in {root}\"")
    sys.exit(1)
tools = set()
for n in ast.walk(ast.parse(srv.read_text())):
    if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)):
        for d in n.decorator_list:
            t = ast.unparse(d)
            if re.match(r"mcp\.tool\b", t):
                m = re.search(r"name\s*=\s*['\"](\w+)['\"]", t)
                tools.add(m.group(1) if m else n.name)
rows = []
for ln in reg.read_text().splitlines():
    if re.match(r"\s*- \{", ln):
        rows.append({k: v.strip() for k, v in re.findall(r"(\w+):\s*([^,}]+)", ln)})
bad = []
for r in rows:
    door, tool = r.get("door", ""), r.get("tool", "")
    exists = (root / door).is_file()
    if "when" in r and not exists:
        continue
    if not exists:
        bad.append((tool, f"the door {door} is not in the tree"))
    if tool not in tools:
        bad.append((tool, f"bin/mcp/ymir-mcp.py registers no tool named {tool}"))
print(f"mcp-parity-guard[{len(bad) or 1}]{{tool,finding}}:")
for t, why in bad or [("-", f"all {len(rows)} doors have their tool")]:
    print(f'  "{t}","{why}"')
sys.exit(1 if bad else 0)
PY
