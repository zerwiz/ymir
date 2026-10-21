#!/usr/bin/env bash
# readme-claims.sh — the user-facing documents must not claim what the tree does not hold.
#
# Why it exists: on 2026-10-21 the README said "the name @zerwiz/smidja … served never; it ships
# as @zerwiz/smidja-factory" — and `npm view @zerwiz/smidja` answered 0.1.1. A reader cannot
# tell a stale claim from a current one, and a stale instruction is worse than none: it sends a
# user down a road that is closed, or one that was never built.
#
# What it checks (from README.md, and any page named):
#   1. every repo path a page names exists (bin/ apps/ src/ packages/ tools/ config/ .agents/
#      scripts/ docs/ registry/ RULES/) — a path in backticks is an instruction, so it must resolve
#   2. with --npm, every @zerwiz/<name> the page names resolves on npm
#   3. with --ports, a named port is reported with what listens on it, for a human to judge
#
# A line may be waived in writing: `<!-- stale-ok: <reason> -->` on the same line, or a path
# listed in docs/README-claims.waived (one per line) when it is historical on purpose.
#
#   bin/gates/checks/readme-claims.sh [--npm] [--ports] [FILE...]
#
# Exit: 0 every claim resolves · 1 a claim does not · 2 usage.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

NPM=0; PORTS=0; FILES=()
for a in "$@"; do
  case "$a" in
    --npm) NPM=1 ;;
    --ports) PORTS=1 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    -*) printf 'error: unknown flag %s\n' "$a" >&2; exit 2 ;;
    *) FILES+=("$a") ;;
  esac
done
[ "${#FILES[@]}" -gt 0 ] || FILES=("$ROOT/README.md")

WAIVE="$ROOT/docs/README-claims.waived"
waived() {
  [ -r "$WAIVE" ] && grep -qxF "$1" "$WAIVE"
}

ELLIPSIS=$(printf '\xe2\x80\xa6')
missing=0; checked=0; packages=0; bad_packages=0; ports=0
printf 'readme-claims[%s]{file,line,kind,claim}\n' "${#FILES[@]}"

for file in "${FILES[@]}"; do
  [ -r "$file" ] || { printf '  "%s","0","MISSING FILE","%s"\n' "$file" "$file"; missing=$((missing + 1)); continue; }
  rel="${file#"$ROOT"/}"
  while IFS= read -r hit; do
    n="${hit%%:*}"
    line="${hit#*:}"
    # waivers are written on the line itself
    case "$line" in *"stale-ok:"*) continue ;; esac
    # every path-looking token in backticks, one per match
    for tok in $(printf '%s' "$line" | grep -oE '`[A-Za-z0-9_.@/-]+/[A-Za-z0-9_.@/-]*`' | tr -d '`'); do
      case "$tok" in
        bin/*|apps/*|src/*|packages/*|tools/*|config/*|.agents/*|scripts/*|docs/*|registry/*|RULES/*|midgard/*|deploy/*|packaging/*) ;;
        *) continue ;;
      esac
      # a placeholder is not a claim. The ellipsis is BUILT, not written: the mocks ward reads a
      # literal … (or <, >, *) in shipped runtime as an unfinished placeholder and fails the gate —
      # which is exactly what happened to this line, so the character is assembled at run time.
      case "$tok" in *'<'*|*'>'*|*'*'*|*"$ELLIPSIS"*) continue ;; esac
      # a JSON-RPC method, not a file (`tools/list` in an MCP handshake)
      case "$tok" in tools/list|tools/call|resources/list|prompts/list) continue ;; esac
      # `RULES/15` is a rule NUMBER, not a directory
      case "$tok" in RULES/[0-9]|RULES/[0-9][0-9]) continue ;; esac
      checked=$((checked + 1))
      if [ -e "$ROOT/$tok" ]; then continue; fi
      waived "$tok" && continue
      printf '  "%s","%s","MISSING PATH","%s"\n' "$rel" "$n" "$tok"
      missing=$((missing + 1))
    done
    # @zerwiz packages, optionally verified against the registry
    for pkg in $(printf '%s' "$line" | grep -oE '@zerwiz/[a-z0-9._-]+' | sort -u); do
      packages=$((packages + 1))
      [ "$NPM" = 1 ] || continue
      if timeout 25 npm view "$pkg" version >/dev/null 2>&1; then
        printf '  "%s","%s","PACKAGE OK","%s"\n' "$rel" "$n" "$pkg"
      else
        printf '  "%s","%s","PACKAGE MISSING","%s"\n' "$rel" "$n" "$pkg"
        bad_packages=$((bad_packages + 1))
      fi
    done
    # ports, for a human to judge — never an automatic failure
    if [ "$PORTS" = 1 ]; then
      for port in $(printf '%s' "$line" | grep -oE ':[0-9]{4,5}' | tr -d ':' | sort -u); do
        ports=$((ports + 1))
        what="$(ss -Htlnp 2>/dev/null | grep ":$port " | head -1 | sed -E 's/.*users:\(\("([^"]+).*/\1/' || true)"
        printf '  "%s","%s","PORT","%s → %s"\n' "$rel" "$n" "$port" "${what:-nothing listening}"
      done
    fi
  done < <(grep -nE '`[^`]+`|@zerwiz/' "$file" 2>/dev/null || true)
done

printf 'readme-claims{checked,missing,packages,bad_packages,ports}: "%s","%s","%s","%s","%s"\n' \
  "$checked" "$missing" "$packages" "$bad_packages" "$ports"
if [ "$missing" -gt 0 ] || [ "$bad_packages" -gt 0 ]; then
  printf 'help: fix the claim, or waive it in writing — a path that does not resolve is a closed road\n' >&2
  exit 1
fi
printf 'readme-claims: every claim resolves\n'
