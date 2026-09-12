#!/usr/bin/env bash
# Gate: validate scripts are POSIX-portable (Mac/Linux/Windows).
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

violations=0
for f in $(find . -type f -name "*.sh" -not -path './.git/*' -not -path './.compliance/gates/*' -not -path './.agents/skills/NSRcompliance/*' -not -path './.agents/skills/NSR/*' -not -path './.agents/skills/NSR-SKILLMAKER/*' -not -path './mockprojectroot/*'); do
  for cmd in 'taskkill' 'pkill' 'kill -9'; do
    if grep -qE "$cmd" "$f" 2>/dev/null; then
      echo "[check_platform] NON-PORTABLE: $f uses '$cmd'"
      violations=1
    fi
  done
  if grep -q $'\r' "$f" 2>/dev/null; then
    echo "[check_platform] CRLF in $f"
    violations=1
  fi
done

[ "$violations" -ne 0 ] && { echo "[check_platform] FAIL"; exit 1; }
echo "[check_platform] PASS"
exit 0