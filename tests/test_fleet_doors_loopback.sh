#!/usr/bin/env bash
# test_fleet_doors_loopback.sh — the fleet's doors face loopback, and Skuld can start (2026-11-12).
#
# Found on a fresh install on a stock Fedora laptop, whose default firewall zone admits every high port:
#   · cards (python http.server), skills-mcp (mcp-proxy), Ratatoskr (Bun.serve) and Skuld/Snotra (node)
#     all listened on every interface with no credential — Ratatoskr's executor reads the well;
#   · Skuld and Snotra sent `access-control-allow-origin: *`, so any web page could drive them;
#   · Skuld's deploy shipped server.mjs without the ledger.mjs it imports, and nothing declared the SDK.
#
# Static checks only — nothing is started, nothing on the machine is touched.
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
U="$ROOT/tools/mill/systemd"
fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

# 1. no unit template binds every interface, and each takes the bind from config
for u in cards skills-mcp skuld ratatoskr snotra; do
  f="$U/$u.service"
  if grep -qE '0\.0\.0\.0' "$f"; then bad "$u.service names 0.0.0.0"; else ok "$u.service names no all-interfaces bind"; fi
  grep -q '^Environment=YMIR_FLEET_BIND=127.0.0.1$' "$f" && grep -q '^EnvironmentFile=-%h/.config/ymir/fleet.env$' "$f" \
    && ok "$u.service: loopback default, widened only by fleet.env" || bad "$u.service: no loopback default"
done
grep -q -- '--bind \${YMIR_FLEET_BIND}' "$U/cards.service" && ok "cards binds \${YMIR_FLEET_BIND}" || bad "cards ignores the bind"
grep -q -- '--host \${YMIR_FLEET_BIND}' "$U/skills-mcp.service" && ok "skills-mcp binds \${YMIR_FLEET_BIND}" || bad "skills-mcp ignores the bind"

# 2. the servers default to loopback and carry no wildcard CORS
for s in tools/tickets-mcp/server.mjs tools/snotra/server.mjs; do
  f="$ROOT/$s"
  grep -q '"0.0.0.0"' "$f" && bad "$s listens on 0.0.0.0" || ok "$s has no hardcoded 0.0.0.0"
  grep -q 'listen(PORT, BIND)' "$f" && ok "$s listens on BIND" || bad "$s does not listen on BIND"
  grep -q '"access-control-allow-origin": "\*"' "$f" && bad "$s sends wildcard CORS" || ok "$s sends no wildcard CORS"
  grep -q 'if (!originAllowed(req)) { res.writeHead(403)' "$f" && ok "$s refuses a foreign origin" || bad "$s does not refuse a foreign origin"
done
grep -q 'hostname: HOST' "$ROOT/packages/a2a/ratatoskr/server.ts" && grep -q '|| "127.0.0.1"' "$ROOT/packages/a2a/ratatoskr/server.ts" \
  && ok "Ratatoskr binds a loopback-default HOST" || bad "Ratatoskr binds every interface"

# 3. no database password ships in the Skuld unit
grep -qE '^Environment=SKULD_PGPASSWORD=' "$U/skuld.service" && bad "skuld.service ships a database password" || ok "skuld.service ships no database password"

# 4. Skuld can start: its module and its pinned dependencies are deployed
E="$ROOT/bin/fleet/fleet-ensure.sh"
grep -q '"tools/tickets-mcp/ledger.mjs:ledger.mjs"' "$E" && ok "the deploy ships ledger.mjs" || bad "the deploy omits ledger.mjs"
[ -f "$ROOT/tools/tickets-mcp/package.json" ] && [ -f "$ROOT/tools/tickets-mcp/package-lock.json" ] \
  && ok "the SDK and zod are declared and locked" || bad "the doors' dependencies are undeclared"
grep -q 'npm ci --omit=dev --ignore-scripts' "$E" && ok "dependencies install with scripts off" || bad "dependencies are not installed, or run scripts"

# 5. the agent card does not publish the LAN address by default
grep -q 'hostname -I' "$E" && bad "the agent card still publishes the LAN address" || ok "the agent card URL is loopback unless named"

exit "$fail"
