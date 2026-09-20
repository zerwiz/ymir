#!/usr/bin/env bash
# app-build — build the in-tree apps (plan 35).
#
# apps/ ships as source, so the bundle each surface serves must be built from it
# before the package is packed. This is the one door that does that, so a build
# cannot be half-done in one place and forgotten in another (the fault class of
# 2026-09-18: an artefact published without the file it needed).
#
#   bin/app-build.sh [surface …]      default: every app that carries a build script
#
# Skips an app that has no package.json (smidja's engine is Python; the smithy
# arrives as @zerwiz/smidja-factory) and an app with no build script, naming it.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
want=("$@")
[ ${#want[@]} -eq 0 ] && want=(hlidskjalf odrerir sessrumnir)

built=0 skipped=0 failed=0
for s in "${want[@]}"; do
  d="$ROOT/apps/$s"
  if [ ! -f "$d/package.json" ]; then
    printf 'app-build[1]{%s}:\n  "skipped — no package.json (not an npm app)"\n' "$s"; skipped=$((skipped+1)); continue
  fi
  if ! grep -q '"build"' "$d/package.json"; then
    printf 'app-build[1]{%s}:\n  "skipped — no build script"\n' "$s"; skipped=$((skipped+1)); continue
  fi
  printf 'app-build[1]{%s}:\n  "building…"\n' "$s"
  if ( cd "$d" && { [ -d node_modules ] || npm install --no-audit --no-fund >/dev/null 2>&1; } && npm run build >/dev/null 2>&1 ); then
    printf 'app-build[1]{%s}:\n  "built — dist/"\n' "$s"; built=$((built+1))
  else
    printf 'app-build[1]{%s}:\n  "FAILED — see its output above"\n' "$s"; failed=$((failed+1))
  fi
done
printf 'app-build[1]{built,skipped,failed}:\n  "%d","%d","%d"\n' "$built" "$skipped" "$failed"
[ "$failed" -eq 0 ] || exit 1
