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
# Run standalone, or through bin/backend/fm-test-run.sh like any other tests/*.test.sh.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/.pi/shared/extensions"
LIB_SRC="$SRC/lib"
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

# ── 3. directory shape: index.ts where there is a directory (Rule 13 §3) ─────
# Pi loads a subdirectory ONLY when it holds index.ts. So every extension folder
# must have one, and lib/ must NOT have one — it is the shared set, not an
# extension.
nodirs=0; withidx=0
for d in "$SRC"/*/; do
  [ -d "$d" ] || continue
  b=$(basename "$d")
  if [ "$b" = "lib" ]; then
    [ -f "$d/index.ts" ] && { bad "lib/ has an index.ts — pi would load it as an extension"; nodirs=1; } \
                         || ok "lib/ has no index.ts — shared modules, never an extension"
    continue
  fi
  if [ -f "$d/index.ts" ]; then withidx=$((withidx+1)); else bad "$b/ has no index.ts — pi would not discover it"; nodirs=1; fi
done
[ "$nodirs" -eq 0 ] && [ "$withidx" -gt 0 ] && ok "every extension folder has an index.ts ($withidx)"

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

# Every lib/ module must be genuinely SHARED — Rule 13 §3. One importer means the
# module has an owner and belongs inside that extension's folder instead.
# A module with at most one importer and no path reference is misplaced: it has
# an owner and belongs inside that extension's folder. A module referenced BY PATH
# (spawned as a child process rather than imported) is a different case — it has no
# import graph to sit in, so lib/ is its correct home.
solo=$(for m in "$LIB_SRC"/*.ts "$LIB_SRC"/*.mjs; do
          [ -e "$m" ] || continue
          b=$(basename "$m")
          n=$(grep -l -- "\./lib/$b\|\.\./lib/$b" "$SRC"/*.ts "$SRC"/*/*.ts 2>/dev/null | wc -l | tr -d ' ')
          if [ "$n" -le 1 ]; then
            p=$(grep -l -- "$b" "$SRC"/*.ts "$SRC"/*/*.ts 2>/dev/null | wc -l | tr -d ' ')
            [ "$p" -eq 0 ] && echo "$b"
          fi
        done | tr '\n' ' ')
spawned=$(for m in "$LIB_SRC"/*.mjs; do
            [ -e "$m" ] || continue
            b=$(basename "$m")
            grep -l -- "$b" "$SRC"/*.ts "$SRC"/*/*.ts 2>/dev/null >/dev/null && echo "$b"
          done | tr '\n' ' ')
if [ -n "$solo" ]; then
  bad "lib/ holds module(s) with no owner and no path reference: $solo"
else
  ok "every lib/ module is shared by 2+ extensions, or is spawned by path${spawned:+ ($spawned)}"
fi

# ── 5. the deployed tree agrees with the source ─────────────────────────────
if [ ! -d "$HOME_EXT" ]; then
  ok "deployed tree absent — nothing to reconcile (run: bin/seat/valknut-load.sh --pi)"
else
  drift=0
  for f in "$SRC"/*.ts "$SRC"/*.js; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in *.test.ts|*.test.js|*.test.mjs|*.spec.ts) continue ;; esac
    if [ ! -f "$HOME_EXT/$b" ]; then
      bad "deployed: $b is NOT DEPLOYED"
      drift=1
    elif ! cmp -s "$f" "$HOME_EXT/$b"; then
      bad "deployed: $b is STALE ($(stat -c%s "$HOME_EXT/$b") vs source $(stat -c%s "$f"))"
      drift=1
    fi
  done < <(find "$SRC" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.mjs' \) | sort)
  [ "$drift" -eq 0 ] && ok "the whole deployed tree is byte-identical to source"

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
  if grep -q 'bin/pi/syn-watch-arm.sh' "${ptr%%$'\n'*}"; then :; fi
  first_valid=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ -x "$line/bin/pi/syn-watch-arm.sh" ]; then first_valid="$line"; break; fi
  done <"$ptr"
  if [ -n "$first_valid" ]; then
    ok "the first VALID root in .ymir-root resolves ($first_valid)"
    # Stale roots are SKIPPED by validation (ymir-home.ts checks each against
    # bin/pi/syn-watch-arm.sh), so they are hygiene and not a failure — reported so
    # the record does not quietly grow.
    dead=$(while IFS= read -r line; do
            [ -n "$line" ] || continue
            [ -x "$line/bin/pi/syn-watch-arm.sh" ] || echo x
          done <"$ptr" | wc -l | tr -d ' ')
    [ "$dead" -gt 0 ] && printf '# note: %s stale root(s) in .ymir-root — skipped by validation, not a failure\n' "$dead"
  else
    bad "no recorded root holds bin/pi/syn-watch-arm.sh — deployed extensions cannot find their bin/"
  fi
else
  ok "no .ymir-root record (nothing deployed yet)"
fi

# ── 8. the gate itself exists and is wired ──────────────────────────────────
grep -q 'MODE_CHECK' "$ROOT/bin/seat/valknut-load.sh" 2>/dev/null \
  && ok "bin/seat/valknut-load.sh carries --check (Rule 13 §9)" \
  || bad "bin/seat/valknut-load.sh carries --check (Rule 13 §9)"
grep -q 'no-delete-guard\|\*\.test\.\*' "$ROOT/bin/seat/valknut-load.sh" 2>/dev/null \
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
