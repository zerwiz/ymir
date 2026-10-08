#!/usr/bin/env bash
# pi-extensions.test.sh — the smoke test for Rule 13, the Pi extension surface.
#
# WHY THIS EXISTS (measured 2026-10-04, rewritten 2026-10-07): nothing in the
# extension tree is wrong in a way that throws. Two load paths seat nobody, a stale
# deploy is invisible, and the doc that governs it can answer "where does an
# extension live?" two incompatible ways — and every file listing still looks right.
#
# Rule 13 in one line, since ac5fd8ad (2026-10-04): ONE HOME per extension, and that
# home is the repo's `.pi/extensions/`. Pi loads BOTH the project tree and the global
# `~/.pi/agent/extensions/` and does not de-duplicate, so an extension in both makes
# pi exit with a tool-name conflict — no agent can be seated. Nothing is deployed.
#
# Run standalone, or through bin/backend/fm-test-run.sh like any other tests/*.test.sh.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_TREE="$ROOT/.pi/extensions"          # THE home (source of truth)
HOME_EXT="${PI_EXT_HOME:-$HOME/.pi/agent/extensions}"   # global; must hold NO extension

fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

# ── 0. the rule exists and is registered ────────────────────────────────────
[ -f "$ROOT/RULES/13-pi-extensions.md" ] \
  && ok "Rule 13 exists" || bad "Rule 13 exists at RULES/13-pi-extensions.md"
grep -q '13-pi-extensions.md' "$ROOT/RULES/README.md" 2>/dev/null \
  && ok "Rule 13 is registered in RULES/README.md" || bad "Rule 13 is registered in RULES/README.md"
grep -q 'RULES/13-pi-extensions.md' "$ROOT/AGENTS.md" 2>/dev/null \
  && ok "Rule 13 is reachable from the always-loaded contract (AGENTS.md)" \
  || bad "Rule 13 is reachable from the always-loaded contract (AGENTS.md)"

# ── 1. the ONE home holds extensions ────────────────────────────────────────
[ -d "$HOME_TREE" ] && ok "the home exists: .pi/extensions/" \
  || { bad "the home exists: .pi/extensions/"; printf '1..0 # skip no home tree\n'; exit 1; }
n_src=$(find "$HOME_TREE" -maxdepth 1 -type f \( -name '*.ts' -o -name '*.js' \) | wc -l | tr -d ' ')
[ "$n_src" -gt 0 ] && ok "the home holds extensions ($n_src)" || bad "the home holds extensions"
[ -d "$ROOT/.pi/shared/extensions" ] \
  && bad ".pi/shared/extensions/ still exists — the retired two-home source" \
  || ok ".pi/shared/extensions/ is gone (one home)"

# ── 2. directory shape: index.ts where there is a directory (Rule 13 §3) ─────
# Pi loads a subdirectory ONLY when it holds index.ts. lib/ is the helper tree and
# must NOT have one.
nodirs=0; withidx=0
for d in "$HOME_TREE"/*/; do
  [ -d "$d" ] || continue
  b=$(basename "$d")
  if [ "$b" = "lib" ]; then
    [ -f "$d/index.ts" ] && { bad "lib/ has an index.ts — pi would load it as an extension"; nodirs=1; } \
                         || ok "lib/ has no index.ts — helper modules, never an extension"
    continue
  fi
  if [ -f "$d/index.ts" ]; then withidx=$((withidx+1)); else bad "$b/ has no index.ts — pi would not discover it"; nodirs=1; fi
done
[ "$nodirs" -eq 0 ] && [ "$withidx" -gt 0 ] && ok "every extension folder has an index.ts ($withidx)"

# ── 3. every relative import resolves IN THE HOME (where pi loads it) ────────
TMP_MISSING=$(mktemp); trap 'rm -f "$TMP_MISSING"' EXIT
for f in "$HOME_TREE"/*.ts "$HOME_TREE"/*.js "$HOME_TREE"/*/*.ts; do
  [ -e "$f" ] || continue
  d="$(dirname "$f")"
  grep -oE 'from[[:space:]]+"\./[^"]+"' "$f" 2>/dev/null | sed 's/.*"\(\(\.[^"]*\)\)"/\1/' | while read -r rel; do
    [ -n "$rel" ] || continue
    [ -e "$d/$rel" ] || echo "        missing: $rel (in $(basename "$f"))" >&2
  done
done > "$TMP_MISSING" 2>&1
if [ -s "$TMP_MISSING" ]; then bad "every relative import resolves in the home"; cat "$TMP_MISSING" >&2
else ok "every relative import resolves in the home"; fi

# ── 4. no extension in TWO load paths (Rule 13 §1) ──────────────────────────
if [ ! -d "$HOME_EXT" ]; then
  ok "the global home is absent — nothing can double-register"
else
  dupe=0
  for ext in "$HOME_TREE"/*; do
    [ -e "$ext" ] || continue
    b=$(basename "$ext")
    case "$b" in node_modules|lib) continue ;; esac
    if [ -e "$HOME_EXT/$b" ]; then
      bad "DUPLICATE: $b stands in both .pi/extensions/ and ~/.pi/agent/extensions/ — registers twice"
      dupe=1
    fi
  done
  [ "$dupe" -eq 0 ] && ok "no extension is present in two load paths"
fi

# ── 5. the root record resolves (walk, never count — Rule 12) ───────────────
ptr="$HOME_EXT/.ymir-root"
found=""
if [ -r "$ptr" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    { [ -d "$line/bin" ] && [ -d "$line/.pi" ]; } && { found="$line"; break; }
  done <"$ptr"
fi
if [ -n "$found" ]; then
  ok "the recorded root resolves to a Ymir tree ($found)"
else
  # No record: the extensions can still walk up from their own directory.
  { [ -d "$HOME_TREE/../.." ] && [ -d "$ROOT/bin" ]; } \
    && ok "no .ymir-root record — the home resolves by walk-up" \
    || bad "no usable root: neither .ymir-root nor a walk-up finds the tree owning bin/"
fi

# ── 6. the gate exists and the loader keeps one home ────────────────────────
grep -q 'MODE_CHECK' "$ROOT/bin/seat/valknut-load.sh" 2>/dev/null \
  && ok "bin/seat/valknut-load.sh carries --check (Rule 13 §9)" \
  || bad "bin/seat/valknut-load.sh carries --check (Rule 13 §9)"
grep -q 'PI_EXT_HOME' "$ROOT/bin/seat/valknut-load.sh" 2>/dev/null \
  && ok "the loader prunes any duplicate from the global home" \
  || bad "the loader does not keep the global home clear of duplicates"

# ── 7. the docs answer the question once ────────────────────────────────────
ASSET="$ROOT/.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md"
if [ -f "$ASSET" ]; then
  stale=$(grep -c '\.pi/shared/extensions/' "$ASSET" 2>/dev/null)
  [ "$stale" -eq 0 ] \
    && ok "the harness-integration asset names no retired .pi/shared/extensions/ path" \
    || bad "the harness-integration asset still points $stale path(s) at .pi/shared/extensions/"
else
  ok "harness-integration asset absent — nothing to contradict"
fi

if [ "$fail" -eq 0 ]; then printf '# pi-extensions: all checks pass\n'; else printf '# pi-extensions: FAILURES above\n' >&2; fi
exit "$fail"
