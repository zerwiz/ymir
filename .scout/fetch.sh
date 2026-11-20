#!/usr/bin/env bash
# fetch.sh <slug> <url> -> raw/<slug>.html + txt/<slug>.md
set -u
S="$(cd "$(dirname "$0")" && pwd)"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
slug="$1"; url="$2"
code=$(timeout 40 curl -sSL -A "$UA" -H 'Accept-Language: en' -o "$S/raw/$slug.html" -w '%{http_code}' "$url" 2>/dev/null)
size=$(stat -c%s "$S/raw/$slug.html" 2>/dev/null || echo 0)
if [ "$code" = "200" ] && [ "$size" -gt 2000 ]; then
  host=$(echo "$url" | sed -E 's#https?://([^/]+).*#\1#')
  python3 "$S/h2md.py" "$S/raw/$slug.html" "$host" > "$S/txt/$slug.md" 2>/dev/null
  echo "OK   $slug  http=$code html=${size}B md=$(wc -w < "$S/txt/$slug.md")w  <- $url"
else
  echo "FAIL $slug  http=$code html=${size}B  <- $url"
fi
