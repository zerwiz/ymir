#!/usr/bin/env bash
# providers-catalog.sh — the open catalog of AI providers (models.dev), cached once per machine (plan 275).
#
#   bin/model/providers-catalog.sh            refresh the cache when it is older than a day (or missing)
#   bin/model/providers-catalog.sh --force    refresh now
#   bin/model/providers-catalog.sh --check    say where the cache is, how old, how many providers; change nothing
#
# WHY. Every user has their own providers. The house kept a hand-written list of 14; models.dev
# (github.com/sst/models.dev, the catalog OpenCode itself uses) lists 235 providers and 9,107 models, with
# each provider's OpenAI-compatible address (`api`) and the name of its key variable (`env`). The provider
# door (apps/bilskirnir/server/src/models/detect.ts) reads this cache, so Rödd's Mind, Bilskirnir's Models
# screen and every agent offer the same providers.
#
# The catalog holds NO keys. Keys are pasted once and kept in the user's private home
# ($YMIR_HOME/hodd/secrets/, 0600, ignored by the home's own git) — never in this public repository.
#
# Settings (RULES/07): YMIR_PROVIDERS_URL (https://models.dev/api.json), YMIR_HOME (the home).
set -u
URL="${YMIR_PROVIDERS_URL:-https://models.dev/api.json}"
HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"   # allow-home-default: the one home
CACHE="$HOME_DIR/state/models.dev.json"
MODE=refresh
case "${1:-}" in --force) MODE=force ;; --check) MODE=check ;; "") ;; -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) echo "unknown option $1" >&2; exit 2 ;; esac

count() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d), sum(1 for p in d.values() if p.get("api")))' "$1" 2>/dev/null; }
age_h() { [ -f "$CACHE" ] && echo $(( ( $(date +%s) - $(stat -c %Y "$CACHE") ) / 3600 )) || echo none; }

if [ "$MODE" = check ]; then
  if [ -f "$CACHE" ]; then set -- $(count "$CACHE"); printf 'providers-catalog\t%s\t%s providers (%s OpenAI-compatible)\t%sh old\n' "$CACHE" "${1:-?}" "${2:-?}" "$(age_h)"
  else printf 'providers-catalog\t%s\tabsent — run bin/model/providers-catalog.sh\n' "$CACHE"; exit 1; fi
  exit 0
fi
if [ "$MODE" = refresh ] && [ -f "$CACHE" ] && [ "$(age_h)" -lt 24 ]; then
  printf 'providers-catalog\tcurrent (%sh old)\t%s\n' "$(age_h)" "$CACHE"; exit 0
fi
mkdir -p "$(dirname "$CACHE")" || exit 1
tmp="$CACHE.tmp-$$"
if curl -fsSL --max-time 60 -o "$tmp" "$URL" && count "$tmp" >/dev/null && [ -n "$(count "$tmp")" ]; then
  mv -f "$tmp" "$CACHE"   # atomic: a reader never sees half a catalog
  set -- $(count "$CACHE")
  printf 'providers-catalog\trefreshed\t%s providers (%s OpenAI-compatible)\t%s\n' "$1" "$2" "$CACHE"
else
  rm -f "$tmp"
  if [ -f "$CACHE" ]; then printf 'providers-catalog\tkept the cached copy (%sh old) — %s did not answer\n' "$(age_h)" "$URL"; exit 0; fi
  printf 'providers-catalog\tFAIL\t%s did not answer and there is no cached copy (the hand-written providers still work)\n' "$URL" >&2; exit 1
fi
