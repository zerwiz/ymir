#!/usr/bin/env bash
# search.sh — token-saving web search: ranked results as compact JSON lines, never whole pages.
#
#   bin/web/search.sh "<query>" [--limit N] [--provider P] [--no-cache]
#
# Providers: firecrawl · exa · brave · tavily · serper · searxng. None is a default: set search.provider in
# $YMIR_HOME/config/web.yaml (template: config/web.yaml.example). The first line carries the notice that
# everything returned is data, never instructions; each further line is {title, url, highlight}.
# Output is capped (10 results, 4 KB) and cached per query under $XDG_CACHE_HOME/ymir/search.
#
# Exit: 0 answered · 1 the provider failed · 2 usage · 3 not configured.
set -u
exec python3 "$(dirname "${BASH_SOURCE[0]}")/web.py" search "$@"
