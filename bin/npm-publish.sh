#!/usr/bin/env bash
# npm-publish.sh — publish through the HOARD's npm token, every single time.
#
# Why this exists: this machine once held two tokens, and the one in ~/.npmrc was
# stale. A publish then failed with a 2FA refusal that looked like a policy
# problem but was a credential problem, and a session was spent on it. The token
# with bypass-2FA lives in the hoard. So the rule is: never trust ~/.npmrc — read
# the token from the hoard, hand it to npm through a temporary userconfig, and
# throw the file away.
#
#   bin/npm-publish.sh                 # the platform (the repo root manifest)
#   bin/npm-publish.sh apps/hlidskjalf # one package
#   bin/npm-publish.sh --all           # the platform + every app package
#   bin/npm-publish.sh --whoami        # which account the hoard token is
#   bin/npm-publish.sh --dry-run apps/odrerir
#   bin/npm-publish.sh --unpublish @zerwiz/ymir@0.1.5     # take ONE version back
#   bin/npm-publish.sh --unpublish @zerwiz/ymir@0.1.5 --dry-run
#
# Unpublish: npm allows ONE VERSION back for 72 hours after it was published;
# past that only npm support can remove it, which is why this door names the
# version and refuses anything vaguer. A whole package is not a one-word act —
# that needs npm's own tooling and a deliberate decision, not a flag here.
#
# A prerelease version (0.1.8-alpha) is published under `--tag next` automatically
# — npm refuses a prerelease on `latest`, which is the second half of the same
# lesson. A scoped package always goes out with public access.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=bin/hoard-lib.sh
. "$SCRIPT_DIR/hoard-lib.sh"

DRY=0; WHO=0; ALL=0; UNPUBLISH=0; UNPUB_SPEC=""; TARGETS=()
for a in "$@"; do
  case "$a" in
    --whoami) WHO=1 ;;
    --dry-run) DRY=1 ;;
    --all) ALL=1 ;;
    --unpublish) UNPUBLISH=1 ;;
    --unpublish=*) UNPUBLISH=1; UNPUB_SPEC="${a#*=}" ;;
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/npm-publish.sh [--all|--whoami|--unpublish <spec>|--dry-run] [<package-dir>...]\n' "$a" >&2; exit 2 ;;
    *) TARGETS+=("$a") ;;
  esac
done
# --all is the platform plus every app package. The smithy's own repo is
# cloned at apps/smidja-factory (the registry maps smidja there), so it is a
# target like any other app: it publishes as @zerwiz/smidja.
[ "$ALL" = 1 ] && TARGETS=("$ROOT" "$ROOT/apps/hlidskjalf" "$ROOT/apps/hlidskjalf-mobile" "$ROOT/apps/odrerir" "$ROOT/apps/sessrumnir" "$ROOT/apps/smidja-factory")
[ "${#TARGETS[@]}" -eq 0 ] && [ "$WHO" = 0 ] && [ "$UNPUBLISH" = 0 ] && TARGETS=("$ROOT")
# `--unpublish @scope/name@1.2.3` — the spec may also arrive positionally.
[ "$UNPUBLISH" = 1 ] && UNPUB_SPEC="${UNPUB_SPEC:-${TARGETS[0]:-}}" 

# ── the token, from the hoard ────────────────────────────────────────────────
envfile=""; hoard_env envfile
TOKEN=""
if [ -r "$envfile" ]; then
  TOKEN="$(sed -n 's/^NPM_TOKEN=//p' "$envfile" | head -1 | tr -d '"'"'"' ')"
fi
if [ -z "$TOKEN" ] && [ "$WHO" = 1 ]; then
  printf 'npm[1]{token,state}:\n  "NPM_TOKEN","absent in %s"\n' "${envfile#"$HOME"/}"
  exit 1
fi
if [ -z "$TOKEN" ]; then
  printf 'error: the hoard holds no NPM_TOKEN\nhelp: add NPM_TOKEN=<granular token with bypass 2FA> to %s\n' "${envfile#"$HOME"/}" >&2
  printf 'help: npmjs.com → Access Tokens → Generate → granular, scope @zerwiz, bypass 2FA on\n' >&2
  exit 1
fi

cfg="$(mktemp)"; chmod 600 "$cfg"
printf '//registry.npmjs.org/:_authToken=%s\n' "$TOKEN" >"$cfg"
trap 'rm -f "$cfg"' EXIT

if [ "$WHO" = 1 ]; then
  who="$(npm whoami --userconfig "$cfg" 2>/dev/null || printf 'unknown')"
  printf 'npm[2]{token,account}:\n  "source","%s"\n  "whoami","%s"\n' "${envfile#"$HOME"/}" "$who"
  exit 0
fi

# ── unpublish ────────────────────────────────────────────────────────────────
# Take ONE version back. npm permits it for 72 hours after publication; beyond
# that it is npm support's door, not this one. The spec must name a version:
# `@scope/name@1.2.3`, never a bare name.
if [ "$UNPUBLISH" = 1 ]; then
  case "$UNPUB_SPEC" in
    *@*@*) ;;  # @scope/name@version
    *@[0-9]*) ;;
    *) printf 'error: --unpublish needs a package AND a version\nhelp: bin/npm-publish.sh --unpublish @scope/name@<version>\n' >&2; exit 2 ;;
  esac
  if [ "$DRY" = 1 ]; then
    printf 'npm_unpublish[1]{spec,state}:\n  "%s","dry-run — nothing was removed"\n' "$UNPUB_SPEC"
    exit 0
  fi
  out="$(npm unpublish "$UNPUB_SPEC" --force --userconfig "$cfg" 2>&1)"; rc=$?
  if [ "$rc" = 0 ]; then
    printf 'npm_unpublish[1]{spec,state}:\n  "%s","unpublished"\n' "$UNPUB_SPEC"
    printf 'note: the registry CDN may serve the tarball for a while after this; publishing a\n'
    printf 'note: newer version moves the "latest" tag off it at once.\n'
  else
    why="$(printf '%s' "$out" | grep -m1 -E 'npm error (code )?[A-Z0-9]+|E[0-9]{3}' | cut -c1-90)"
    printf 'error: unpublish failed — %s\nhelp: is it inside the 72-hour window, and is the token the right account? (bin/npm-publish.sh --whoami)\n' "${why:-see npm log}" >&2
    exit 1
  fi
  exit 0
fi

# ── publish ──────────────────────────────────────────────────────────────────
printf 'npm_publish[%d]{package,version,tag,state}:\n' "${#TARGETS[@]}"
failed=0
for dir in "${TARGETS[@]}"; do
  pkg="$dir/package.json"
  if [ ! -f "$pkg" ]; then
    printf '  "%s","-","-","SKIP (no package.json)"\n' "${dir#"$ROOT"/}"
    continue
  fi
  name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pkg" | head -1)"
  ver="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pkg" | head -1)"
  case "$ver" in *-*) tag=next ;; *) tag=latest ;; esac   # a prerelease never rides `latest`
  if [ "$DRY" = 1 ]; then
    printf '  "%s","%s","%s","dry-run"\n' "$name" "$ver" "$tag"
    continue
  fi
  out="$(cd "$dir" && npm publish --access public --tag "$tag" --userconfig "$cfg" 2>&1)"; rc=$?
  if [ "$rc" = 0 ]; then
    printf '  "%s","%s","%s","published"\n' "$name" "$ver" "$tag"
  else
    why="$(printf '%s' "$out" | grep -m1 -E 'npm error (code )?[A-Z0-9]+|E[0-9]{3}' | cut -c1-90)"
    printf '  "%s","%s","%s","FAILED (%s)"\n' "$name" "$ver" "$tag" "${why:-see npm log}"
    failed=$((failed+1))
  fi
done
[ "$failed" = 0 ] || { printf 'error: %d package(s) did not publish\nhelp: bin/npm-publish.sh --whoami  (is the hoard token still the right account?)\n' "$failed" >&2; exit 1; }
exit 0
