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
# Every surface that SERVES a built bundle must be here. The Smíðja visualizer is
# NESTED (apps/smidja-factory/apps/visualizer) and was missing from this list, so
# its dist/ was never built before packing and the npm package shipped without
# the interface — the API answered, the app view showed nothing (2026-09-23).
# A path may be nested; it is joined onto apps/ below.
[ ${#want[@]} -eq 0 ] && want=(hlidskjalf odrerir sessrumnir smidja-factory/apps/visualizer)

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
  # The build's own output is KEPT. It used to go to /dev/null while the failure
  # line said "see its output above" — above nothing. When CI reported "sessrumnir
  # web surface not built", the log that would have said WHY was thrown away one
  # step earlier (2026-09-30). A build that fails silently is how a tarball ships
  # with no surfaces at all.
  blog="$(mktemp "${TMPDIR:-/tmp}/app-build.XXXXXX.log")"
  if ( cd "$d" && { [ -d node_modules ] || npm install --no-audit --no-fund >"$blog" 2>&1; } && npm run build >>"$blog" 2>&1 ); then
    printf 'app-build[1]{%s}:\n  "built — dist/"\n' "$s"; built=$((built+1))
  else
    printf 'app-build[1]{%s}:\n  "FAILED — build log: %s (last 15 lines follow)"\n' "$s" "$blog"; failed=$((failed+1))
    tail -15 "$blog" | sed 's/^/    /'
  fi
done
printf 'app-build[1]{built,skipped,failed}:\n  "%d","%d","%d"\n' "$built" "$skipped" "$failed"
[ "$failed" -eq 0 ] || exit 1
