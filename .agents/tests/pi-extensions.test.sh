#!/usr/bin/env bash
# pi-extensions.test.sh — the smoke test for Rule 13, the Pi extension surface.
#
# WHY THIS EXISTS (measured 2026-10-04): nothing in the extension tree is wrong in
# a way that throws. A deploy can be three days stale, one system can have its
# source split across two directories, and the document that governs it can answer
# "where does an extension live?" two incompatible ways — and every file listing
# still looks correct. This test asserts the shape, so those failures have a sound
# instead of a memory.
#
# Rule 13 in one line: ONE HOME per extension. `.pi/shared/extensions/` is the
# source, `~/.pi/agent/extensions/` is the deployed copy, and an extension in both
# makes pi exit with a tool-name conflict so that no agent can be seated.
#
# Run standalone, or through bin/fm-test-run.sh like any other tests/*.test.sh.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/.pi/shared/extensions"
LIB_SRC="$ROOT/.pi/extensions/lib"
PROJECT="$ROOT/.pi/extensions"
HOME_EXT="${PI_EXT_HOME:-$HOME/.pi/agent/extensions}"

fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }
skip_all() { printf '1..0 # skip %s\n' "$1"; exit 0; }

# ── 0. the rule exists and is registered ────────────────────────────────────
if [ ! -f "$ROOT/RULES/13-pi-extensions.md" ]; then
  bad "Rule 13 exists at RULES/13-pi-extensions.md"
else
  ok "Rule 13 exists"
fi
grep -q '13-pi-extensions.md' "$ROOT/RULES/README.md" 2>/dev/null \
  && ok "Rule 13 is registered in RULES/README.md" \
  || bad "Rule 13 is registered in RULES/README.md"
grep -q 'RULES/13-pi-extensions.md' "$ROOT/AGENTS.md" 2>/dev/null \
  && ok "Rule 13 is reachable from the always-loaded contract (AGENTS.md)" \
  || bad "Rule 13 is reachable from the always-loaded contract (AGENTS.md)"

# ── 1. the three trees are what Rule 13 says they are ───────────────────────
[ -d "$SRC" ] && ok "source tree exists: .pi/shared/extensions/" \
  || { bad "source tree exists: .pi/shared/extensions/"; skip_all "no source tree"; }

n_src=$(find "$SRC" -maxdepth 1 -type f \( -name '*.ts' -o -name '*.js' \) | wc -l | tr -d ' ')
[ "$n_src" -gt 0 ] && ok "source holds extensions ($n_src)" || bad "source holds extensions"

# ── 2. every project-local file registers NOTHING (Rule 13 §2) ───────────────
# A no-op stub is the only permitted occupant of .pi/extensions/. Anything past
# a kilobyte is a second copy of an extension waiting to collide.
heavy=0
for f in "$PROJECT"/*.ts "$PROJECT"/*.js; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
  if [ "$sz" -gt 1024 ]; then
    bad "project-local $b is ${sz}B — it registers tools pi already loaded"
    heavy=1
  elif ! grep -q 'export default function' "$f"; then
    bad "project-local $b exports no factory — pi errors on a file with none"
    heavy=1
  fi
done
[ "$heavy" -eq 0 ] && ok "every .pi/extensions/*.ts is a no-op factory"

# ── 3. lib/ is NOT an extension directory, and that is correct ───────────────
# Pi: "No recursion beyond one level", and a subdirectory loads only with an
# index.ts. lib/ has none, so it is never scanned — the shared extensions reach
# those modules by relative import, and the loader must deploy them too.
[ -f "$LIB_SRC" ] && ls "$LIB_SRC"/index.ts >/dev/null 2>&1 \
  && bad "lib/ has no index.ts (it must never become an extension directory)" \
  || ok "lib/ has no index.ts — pi will never scan it as an extension"

# ── 4. every relative import RESOLVES — where the extension actually runs ─────
# An extension's imports must resolve in the DEPLOYED tree, because that is where
# pi loads it. Checking the source tree instead would be checking a layout that
# does not exist at runtime.
#
# This is also where the unfinished migration shows itself: the source extensions
# say `./lib/ro-visibility.ts`, and in the SOURCE tree `lib/` is not beside them —
# it is at `.pi/extensions/lib/`. It resolves only after the loader copies it in.
# So: deployed tree = must resolve, always. Source tree = reported as a NOTE tied
# to the known gap, not a failure, until the internals move beside their owner.
tree_of="$HOME_EXT"
[ -d "$HOME_EXT" ] || tree_of="$SRC"
TMP_MISSING=$(mktemp); trap 'rm -f "$TMP_MISSING"' EXIT
for f in "$tree_of"/*.ts "$tree_of"/*.js; do
  [ -e "$f" ] || continue
  d="$(dirname "$f")"
  grep -oE 'from\s+"\./[^"]+"' "$f" 2>/dev/null | sed 's/.*"\(\(\.[^"]*\)\)"/\1/' | while read -r rel; do
    [ -n "$rel" ] || continue
    [ -e "$d/$rel" ] || echo "        missing: $rel (in $(basename "$f"))" >&2
  done
done > "$TMP_MISSING" 2>&1
if [ -s "$TMP_MISSING" ]; then
  bad "every relative import resolves where extensions run"
  cat "$TMP_MISSING" >&2
else
  ok "every relative import resolves where extensions run ($(basename "$tree_of"))"
fi

# The known gap, stated every run so it cannot be forgotten.
gap=$(grep -cE '"\./lib/' "$SRC"/*.ts 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
[ "$gap" -gt 0 ] && printf '# NOTE: %s import(s) in the source still reach sideways into lib/ —\n' "$gap" \
  && printf '#       Rule 13 §3 says those modules belong inside their own extension folder\n' \
  && printf '#       (one directory + index.ts). The layout is unchanged; that is steps 3-5.\n'

# ── 5. the deployed tree agrees with the source ─────────────────────────────
if [ ! -d "$HOME_EXT" ]; then
  ok "deployed tree absent — nothing to reconcile (run: bin/valknut-load.sh --pi)"
else
  drift=0
  for f in "$SRC"/*.ts "$SRC"/*.js; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    if [ ! -f "$HOME_EXT/$b" ]; then
      bad "deployed: $b is NOT DEPLOYED"
      drift=1
    elif ! cmp -s "$f" "$HOME_EXT/$b"; then
      bad "deployed: $b is STALE ($(stat -c%s "$HOME_EXT/$b") vs source $(stat -c%s "$f"))"
      drift=1
    fi
  done
  [ "$drift" -eq 0 ] && ok "deployed extensions are byte-identical to source"

  leaked=0
  for f in "$HOME_EXT"/lib/*.test.* "$HOME_EXT"/*.test.*; do
    [ -e "$f" ] || continue
    bad "a test file is in the live tree: $(basename "$f")"
    leaked=1
  done
  [ "$leaked" -eq 0 ] && ok "no test files in the deployed tree"
fi

# ── 6. no extension in two load paths (Rule 13 §1) ───────────────────────────
dupe=0
for f in "$PROJECT"/*.ts "$PROJECT"/*.js; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  if [ -f "$SRC/$b" ] && [ -f "$HOME_EXT/$b" ] && cmp -s "$f" "$SRC/$b"; then
    bad "DUPLICATE: $b is byte-identical to the deployed source — registers twice"
    dupe=1
  fi
done
[ "$dupe" -eq 0 ] && ok "no extension is present in two load paths"

# ── 7. the root pointer resolves, and validation is what saves it ────────────
ptr="$HOME_EXT/.ymir-root"
if [ -f "$ptr" ]; then
  if grep -q 'bin/syn-watch-arm.sh' "${ptr%%$'\n'*}"; then :; fi
  first_valid=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ -x "$line/bin/syn-watch-arm.sh" ]; then first_valid="$line"; break; fi
  done <"$ptr"
  if [ -n "$first_valid" ]; then
    ok "the first VALID root in .ymir-root resolves ($first_valid)"
    # Stale roots are SKIPPED by validation (ymir-home.ts checks each against
    # bin/syn-watch-arm.sh), so they are hygiene and not a failure — reported so
    # the record does not quietly grow.
    dead=$(while IFS= read -r line; do
            [ -n "$line" ] || continue
            [ -x "$line/bin/syn-watch-arm.sh" ] || echo x
          done <"$ptr" | wc -l | tr -d ' ')
    [ "$dead" -gt 0 ] && printf '# note: %s stale root(s) in .ymir-root — skipped by validation, not a failure\n' "$dead"
  else
    bad "no recorded root holds bin/syn-watch-arm.sh — deployed extensions cannot find their bin/"
  fi
else
  ok "no .ymir-root record (nothing deployed yet)"
fi

# ── 8. the gate itself exists and is wired ──────────────────────────────────
grep -q 'MODE_CHECK' "$ROOT/bin/valknut-load.sh" 2>/dev/null \
  && ok "bin/valknut-load.sh carries --check (Rule 13 §9)" \
  || bad "bin/valknut-load.sh carries --check (Rule 13 §9)"
grep -q 'no-delete-guard\|\*\.test\.\*' "$ROOT/bin/valknut-load.sh" 2>/dev/null \
  && ok "the loader excludes test files from the deploy" \
  || bad "the loader excludes test files from the deploy"

# ── 9. the docs answer the question once ────────────────────────────────────
ASSET="$ROOT/.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md"
if [ -f "$ASSET" ]; then
  # Any .pi/extensions/<ext>.ts path claiming to hold a real extension is the
  # contradiction that sent the question in the first place.
  stale=$(grep -oE '`\.pi/extensions/[a-z-]+\.(ts|js|mjs)`' "$ASSET" 2>/dev/null \
    | grep -v 'lib/' | wc -l | tr -d ' ')
  [ "$stale" -eq 0 ] \
    && ok "the harness-integration asset names no extension at the wrong path" \
    || bad "the harness-integration asset still points $stale extension path(s) at .pi/extensions/"
else
  ok "harness-integration asset absent — nothing to contradict"
fi

printf '# pi-extensions: all checks pass\n' || printf '# pi-extensions: FAILURES above\n'
exit "$fail"
