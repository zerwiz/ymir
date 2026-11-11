#!/usr/bin/env bash
# 0020-the-well-door — take the direct engram out of every harness, and seat the well door.
#
# WHY (2026-11-10, the Allfather's law): *engram is Kaia's engine only.* Every harness — pi,
# opencode, claude, cursor, codex, hermes — reaches memory through the WELL DOOR, this body's
# MCP gateway (`/mcp/well`, :8316), which journals each write and carries it to the heart.
# Older installs wrote a direct `engram-mcp --db <hoard>/memory/kaia.engram` stdio server into
# pi and opencode (bin/bridge/a2a-mcp.sh install), and hands copied it into Claude, Codex and
# Hermes. Writes through it landed in the seat's local file, bypassed the gateway journal and
# never reached the heart. A `git pull` cannot reach those files — they live in $HOME — so this
# migration is the door that does.
#
# WHAT IT DOES — one call to the door that owns the answer:
#   bin/bridge/mcp-config.sh seat — a NAMED merge per harness present on this host, from pi's
#   one set: the direct engram is dropped, the record doors point at the gateway, and every
#   other server the operator seated stays. Each file it changes is backed up first
#   (`<file>.bak-<UTC stamp>`). A harness that is absent is a clean skip (RULES/25).
#
# WHAT IT DELIBERATELY DOES NOT DO:
#   * it never touches Kaia's own direct use — the engine, the bridge on :4602, the store;
#   * it never copies a literal secret from one harness's config into another's;
#   * it never edits ~/.claude.json behind the CLI's back (it uses `claude mcp`).
#
# Idempotent: a second run finds every harness current and changes nothing.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
say() { printf '0020: %s\n' "$1"; }

door="$ROOT/bin/bridge/mcp-config.sh"
[ -x "$door" ] || { say "no bin/bridge/mcp-config.sh in this tree — nothing to seat"; exit 0; }
command -v python3 >/dev/null 2>&1 || { say "no python3 — the harnesses are unchanged (run bin/bridge/mcp-config.sh seat later)"; exit 0; }

out="$("$door" seat 2>&1)"; rc=$?
printf '%s\n' "$out" | sed -n 's/^  "\([^"]*\)","\([^"]*\)",.*/0020: \1 — \2/p'
[ "$rc" = 0 ] || say "a harness could not be seated — bin/bridge/mcp-config.sh seat --check names it"
say "done — engram is Kaia's; every harness drinks through the well door"
exit 0
