#!/usr/bin/env bash
# Gate: validate scripts are POSIX-portable (Mac/Linux/Windows).
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

violations=0
for f in $(find . -type f -name "*.sh" -not -path './.git/*' -not -path './bin/fleet/ymir-platform.sh' -not -path './.yggdrasil/*' -not -path '*/node_modules/*' -not -path './.agents/skills/nsr-compliance/assets/*' -not -path './.compliance/gates/*' -not -path './.agents/skills/NSRcompliance/*' -not -path './.agents/skills/NSR/*' -not -path './.agents/skills/NSR-SKILLMAKER/*' -not -path './mockprojectroot/*' -not -path './bin/gates/guards/pkill-guard.sh'); do
  # A GATE THAT FLAGS ITS OWN GUARD (2026-11-13). The scan counted any line containing the word, so
  # `pkill-guard.sh` — whose whole job is to grep for `pkill` — was reported as a user of it, and so was
  # `guards.sh` for naming the guard. A LINE THAT ONLY SEARCHES FOR A COMMAND IS NOT A USE OF IT: a match
  # is skipped when the same line carries `grep`, `rg` or a quoted pattern in a case arm.
  # `kill -9` may be declared instead of removed: a hung process has no graceful kill. The declaration is a
  # comment on the same line — `# kill: <why>` — so a blunt kill always carries its reason.
  for cmd in 'taskkill' 'pkill' 'kill -9'; do
    hits="$(grep -nE "$cmd" "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' | grep -vE 'grep|rg |case "|=~' | grep -v 'pkill-guard' | grep -vE '# *kill:' || true)"
    [ -z "$hits" ] && continue
    echo "[check_platform] NON-PORTABLE: $f uses '$cmd'"
    printf '%s\n' "$hits" | head -3 | sed 's/^/    /'
    violations=1
  done
  if grep -q $'\r' "$f" 2>/dev/null; then
    echo "[check_platform] CRLF in $f"
    violations=1
  fi
done

[ "$violations" -ne 0 ] && { echo "[check_platform] FAIL"; exit 1; }
echo "[check_platform] PASS"
exit 0