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
#
# 2026-10-24: section 8 covers the WORKTREE case. A Yggdrasil worktree used to check
# `.pi/extensions/` out like any other file, so a pi seat inside it loaded the same
# eighteen extensions twice (the worktree's and the seat's), every tool name
# collided and pi exited — the dispatcher then typed the brief into the bare shell
# that was left. The guard is `bin/forge/yggdrasil.sh create` excluding that path by
# a per-worktree sparse-checkout, plus `valknut-load.sh --check` knowing that a
# worktree of the SAME repository is ONE home and a copy inside it is the fault.
# docs/fixes/seat/2026-10-24-a-worktree-carries-no-second-extension-home.md
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

# ── 8. a Yggdrasil worktree carries no second extension home (2026-10-24) ────
# Hermetic: a scratch repository of its own, so this proves the ROAD without ever
# touching the seat this test runs from. The loader's two overrides (PI_EXT_HOME,
# PI_SETTINGS) are what a machine uses anyway — nothing here is hardcoded.
SCRATCH=$(mktemp -d 2>/dev/null) || SCRATCH=""
if [ -n "$SCRATCH" ]; then
  trap 'rm -rf "$SCRATCH"; rm -f "${TMP_MISSING:-}"' EXIT
  mkdir -p "$SCRATCH/repo/.pi/extensions/lib" "$SCRATCH/repo/bin/pi" "$SCRATCH/repo/bin/seat" "$SCRATCH/repo/RULES"
  echo 'export default 1' > "$SCRATCH/repo/.pi/extensions/one.ts"
  echo 'export default 2' > "$SCRATCH/repo/.pi/extensions/two.ts"
  echo 'helper' > "$SCRATCH/repo/.pi/extensions/lib/h.ts"
  echo 'rule' > "$SCRATCH/repo/RULES/13-pi-extensions.md"
  # `.pi/` keeps other things beside the extensions, as the real tree does
  # (`.pi/agents`, `.pi/shared`, `.pi/mcp-adapter.json`). The loader's root walk
  # keys on `.pi/` existing, so a tree whose `.pi/` held ONLY extensions would
  # resolve past its own worktree to the seat root.
  echo 'agents' > "$SCRATCH/repo/.pi/agents-placeholder.txt"
  echo '#!/usr/bin/env bash' > "$SCRATCH/repo/bin/pi/syn-watch-arm.sh"
  chmod +x "$SCRATCH/repo/bin/pi/syn-watch-arm.sh"
  # The loader resolves ROOT from its OWN location, so the scratch repo carries the
  # loader it is tested with — and its worktree inherits that copy.
  cp "$ROOT/bin/seat/valknut-load.sh" "$SCRATCH/repo/bin/seat/valknut-load.sh"
  chmod +x "$SCRATCH/repo/bin/seat/valknut-load.sh"
  ( cd "$SCRATCH/repo" && git init -q -b main . \
      && git add -A \
      && GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
         git commit -qm init ) >/dev/null 2>&1

  # The worktree road itself.
  "$ROOT/bin/forge/yggdrasil.sh" create proof --repo "$SCRATCH/repo" >/dev/null 2>&1 \
    && ok "yggdrasil.sh create produced a worktree" \
    || bad "yggdrasil.sh create produced a worktree"
  WTP="$SCRATCH/repo/.yggdrasil/proof"
  if [ -e "$WTP/.pi/extensions" ]; then
    bad "the new worktree carries its OWN .pi/extensions — a second load path, no seat"
  else
    ok "the new worktree carries no second extension tree (sparse: not checked out)"
  fi
  [ -z "$(git -C "$WTP" status --porcelain 2>/dev/null)" ] \
    && ok "the exclusion is sparse, not deleted files (worktree status clean)" \
    || bad "the exclusion left the worktree dirty (a symlink or a delete would)"
  git -C "$WTP" sparse-checkout list 2>/dev/null | grep -qxF '!/.pi/extensions/' \
    && ok "the worktree's sparse pattern excludes .pi/extensions/" \
    || bad "the worktree's sparse pattern does not exclude .pi/extensions/"
  [ -d "$SCRATCH/repo/.pi/extensions" ] \
    && ok "the seat's own tree still holds its extensions (untouched)" \
    || bad "the seat's own tree lost its extensions"

  # The gate: a worktree of the same repository is ONE home; a copy inside it is two.
  mkdir -p "$SCRATCH/ext-home"
  printf '%s\n' "$SCRATCH/repo" > "$SCRATCH/ext-home/.ymir-root"
  printf '{"extensions": ["%s"]}\n' "$SCRATCH/repo/.pi/extensions" > "$SCRATCH/settings.json"
  state_of() {  # <tree> -> the loader's state word, asked through THAT tree's own loader
    ( cd "$1" && PI_EXT_HOME="$SCRATCH/ext-home" PI_SETTINGS="$SCRATCH/settings.json" \
        "$1/bin/seat/valknut-load.sh" --ext-home 2>/dev/null | sed -n '2p' | cut -d'"' -f4 )
  }
  check_in() {  # <tree> -> valknut-load --check, run through that tree's own loader
    ( cd "$1" && PI_EXT_HOME="$SCRATCH/ext-home" PI_SETTINGS="$SCRATCH/settings.json" \
        "$1/bin/seat/valknut-load.sh" --check ) >/dev/null 2>&1
  }
  [ "$(state_of "$SCRATCH/repo")" = own ] \
    && ok "the seated tree is its own home (state: own)" \
    || bad "the seated tree is not reported as its own home (got: $(state_of "$SCRATCH/repo"))"
  tree_of() {  # <tree> -> the tree the loader believes it is running in
    ( cd "$1" && PI_EXT_HOME="$SCRATCH/ext-home" PI_SETTINGS="$SCRATCH/settings.json" \
        "$1/bin/seat/valknut-load.sh" --ext-home 2>/dev/null | sed -n '2p' | cut -d'"' -f2 )
  }
  [ "$(tree_of "$WTP")" = "$WTP/.pi/extensions" ] \
    && ok "the sparse worktree is still recognised as its own tree" \
    || bad "the sparse worktree is not recognised as its own tree (got: $(tree_of "$WTP"))"
  [ "$(state_of "$WTP")" = shared ] \
    && ok "a sparse worktree of the seat is ONE home (state: shared)" \
    || bad "a sparse worktree of the seat is not ONE home (got: $(state_of "$WTP"))"
  check_in "$WTP" \
    && ok "valknut-load --check PASSES inside the sparse worktree" \
    || bad "valknut-load --check fails inside the sparse worktree"
  mkdir -p "$WTP/.pi/extensions" && echo 'export default 3' > "$WTP/.pi/extensions/three.ts"
  [ "$(state_of "$WTP")" = shared-copy ] \
    && ok "a worktree that carries its own tree is named as a second home (state: shared-copy)" \
    || bad "a worktree that carries its own tree is not named a second home (got: $(state_of "$WTP"))"
  check_in "$WTP" \
    && bad "valknut-load --check passed with a genuine second home — the guard is blind" \
    || ok "valknut-load --check FAILS when a genuine second home exists"
  rm -rf "$WTP/.pi/extensions"
else
  bad "could not make a scratch directory for the worktree case"
fi

if [ "$fail" -eq 0 ]; then printf '# pi-extensions: all checks pass\n'; else printf '# pi-extensions: FAILURES above\n' >&2; fi
exit "$fail"