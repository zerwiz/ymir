#!/usr/bin/env bash
# release-npm.sh — `ymir release npm <version>`: the npm runbook as one door (plan 365 phase 5).
#
#   release-npm.sh <x.y.z> [--yes] [--skip-clean-home]
#
# A T2 door: it publishes to the public registry, so it runs ONLY when the Allfather triggers it. Without `--yes`
# it is a dry run — it checks every precondition, runs the pretest on the exact tarball and prints what `--yes`
# would do; it publishes nothing and creates no tag. With `--yes` it walks hodd/docs/runbooks/npm-publish.md:
#   1 main is clean and the version is package.json's   2 pretest PASS on the exact tarball   3 tag v<version>
#   4 publish (token from the SEALED hoard into a throwaway userconfig, never echoed)   5 wait for the registry to settle
#   6 clean-HOME install proof.   It stops on the first red row and says which.
# Exit: 0 done (or a clean dry run) · 1 stopped on a red row · 2 usage.
set -u
HERE="$(CDPATH='' command cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' command cd -- "$HERE/../../.." && pwd)"
VER="${1-}"; shift 2>/dev/null || true
YES=0; CLEAN=1
for a in "$@"; do case "$a" in --yes) YES=1 ;; --skip-clean-home) CLEAN=0 ;; *) echo "error: unknown '$a'" >&2; exit 2 ;; esac; done
case "$VER" in [0-9]*.[0-9]*.[0-9]*) ;; *) echo 'usage: ymir release npm <x.y.z> [--yes]' >&2; exit 2 ;; esac
say() { printf '%s\n' "$*"; }
row() { printf '  "%s","%s","%s"\n' "$1" "$2" "$3"; }
say 'release-npm[*]{step,state,detail}:'
stop() { row "$1" red "$2"; say "stopped: $1 — $2"; exit 1; }
[ "$YES" = 1 ] && say '# LIVE: this publishes' || say '# DRY RUN: nothing is published, no tag is made (add --yes to sail)'

# 1. the tree and the version
cd "$ROOT" || exit 1
have="$(node -p "require('./package.json').version" 2>/dev/null)"
[ "$have" = "$VER" ] || stop version "package.json says $have, not $VER — the bump rides the gather PR, never after the merge"
row version green "$VER"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
git fetch -q origin main 2>/dev/null
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main 2>/dev/null)" ]; then stop main "HEAD is not origin/main — ship from main, never from a branch ($branch)"; fi
row main green "HEAD is origin/main"
[ -z "$(git status --porcelain --untracked-files=no)" ] || stop tree "the tree has uncommitted changes"
row tree green clean
if git rev-parse -q --verify "refs/tags/v$VER" >/dev/null; then stop tag "v$VER already exists"; fi
row tag green "v$VER is free"

# the token is held (the name is proved; the value is never printed)
if bash "$ROOT/bin/vault/hodd.sh" names secrets/platform.env 2>/dev/null | grep -qx 'NPM_TOKEN'; then row token green "NPM_TOKEN is held in the sealed hoard"
else stop token "NPM_TOKEN is not held — store it with bin/vault/hodd-set.sh"; fi

# 2. the gate, on the exact tarball
if ( export YMIR_FLEET_DEPLOY=off NPM_PRETEST_SKIP_REMOTE=1; bash "$HERE/npm-pretest.sh" >/tmp/release-npm-pretest.$$ 2>&1 ); then row pretest green "PRETEST PASS"
else tail -3 /tmp/release-npm-pretest.$$ | sed 's/^/  | /'; rm -f /tmp/release-npm-pretest.$$; stop pretest "the pretest failed — nothing sails"; fi
rm -f /tmp/release-npm-pretest.$$

if [ "$YES" != 1 ]; then
  row plan info "with --yes: tag v$VER, push it, npm publish --access public --tag latest, wait for the packument, prove a clean-HOME install"
  exit 0
fi

# 3. tag
git tag -a "v$VER" -m "Ymir $VER" && git push -q origin "v$VER" || stop tag "could not create or push v$VER"
row tag green "v$VER pushed"

# 4. publish — a throwaway userconfig, token never echoed
u="$(umask 077; mktemp)"; trap 'rm -f "$u"' EXIT
t="$(bash "$ROOT/bin/vault/hodd.sh" get secrets/platform.env NPM_TOKEN 2>/dev/null)"
[ -n "$t" ] || stop token "the sealed hoard gave no NPM_TOKEN"
printf '//registry.npmjs.org/:_authToken=%s\n' "$t" >"$u"; unset t
who="$(npm whoami --userconfig "$u" 2>/dev/null)" || stop whoami "npm refused the token (expired? granular tokens last 7–90 days) — rotate it at npmjs.com"
row whoami green "$who"
YMIR_FLEET_DEPLOY=off npm publish --access public --tag latest --userconfig "$u" >/dev/null 2>&1 || stop publish "npm publish failed (a staged number blocks forever: bump forward)"
row publish green "$VER sent"

# 5. settle — the raw packument, cache-busted, up to 10 minutes
ok=0
for _ in $(seq 1 40); do
  curl -s "https://registry.npmjs.org/@zerwiz%2fymir?cb=$RANDOM" | python3 -c "import json,sys;d=json.load(sys.stdin);sys.exit(0 if d['dist-tags']['latest']=='$VER' and '$VER' in d['versions'] else 1)" 2>/dev/null && { ok=1; break; }
  sleep 15
done
[ "$ok" = 1 ] || stop settle "the registry has not shown $VER as latest after 10 minutes — check again, do not republish"
row settle green "latest is $VER"

# 6. clean-HOME proof
if [ "$CLEAN" = 1 ]; then
  S="$(mktemp -d)"
  out="$( export HOME="$S/h" XDG_CONFIG_HOME="$S/h/.config" XDG_DATA_HOME="$S/h/.local/share" YMIR_FLEET_DEPLOY=off
          npm i -g --prefix "$S/pfx" "@zerwiz/ymir@$VER" --cache "$S/c" >/dev/null 2>&1 && "$S/pfx/bin/ymir" --version 2>&1 | tail -1 )"
  rm -rf "$S"
  [ "$out" = "$VER" ] || stop clean-home "a clean-HOME install printed '${out:-nothing}', not $VER"
  row clean-home green "installs and prints $VER"
fi
say "released: @zerwiz/ymir@$VER — now prove it on a second machine (runbook step 7) and settle the dist-tags (step 8)"
