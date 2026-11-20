#!/usr/bin/env bash
# people-guard.sh — the public tree holds no people.
#
# WHY THIS EXISTS (2026-10-21, measured): the public repository carried a collaborator's full name
# and two of his email addresses — in FEATURES.md, in a feature page and in two fix notes — merged
# through the gate. **No guard had the rule**, which is why every ward passed:
#   * `private-guard` watches absolute paths, vault references and secret SHAPES — not names;
#   * Rule 26 explicitly allows "a participant's name" on a meeting record — and a public repository
#     is not a meeting record;
#   * nothing anywhere said "a person is private data".
#
# The rule this enforces: **a person named in the operator's registries is personal data.** Their name
# and their address never appear in this tree — a public artifact is the widest external surface there
# is, and a clone may be indexed, mirrored and copied where a correction cannot follow.
#
#   people-guard.sh check        # the ward (what guards.sh runs)
#   people-guard.sh --scan       # the whole tree, with the offending line
#
# A public figure quoted in research (an author, a project maintainer) is NOT a person from the
# operator's registries, and is not flagged: the list comes from `collaborators.yaml` and the NDA
# register, never from a dictionary of names.
#
# Exit: 0 clean · 1 a person from the registry is in the tree · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CMD="${1:-check}"; shift || true
case "$CMD" in
  check|--scan) ;;
  --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'error: unknown command %s\nhelp: people-guard.sh [check|--scan]\n' "$CMD" >&2; exit 2 ;;
esac

# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'people-guard[1]{state}: "the hoard is unresolved — nothing to compare against"\n'; exit 0; }

REG="$HOME_R/hodd/identity/collaborators.yaml"
CONF="$HOME_R/hodd/identity/confidential.yaml"
[ -r "$REG" ] || [ -r "$CONF" ] || { printf 'people-guard[1]{state}: "no registries yet"\n'; exit 0; }

# The list is built from the registries, one token per line: a full name, and every address.
TOKENS="$(REG_Q="$REG" CONF_Q="$CONF" python3 - <<'PY'
import os, re, sys
tokens = set()
for path in (os.environ["REG_Q"], os.environ["CONF_Q"]):
    try:
        import yaml
        data = yaml.safe_load(open(path)) or {}
    except Exception:
        continue
    def walk(node):
        if isinstance(node, dict):
            for k, v in node.items():
                if k in ("name", "emails", "address", "addresses", "parties", "contacts"):
                    if isinstance(v, str):
                        tokens.add(v.strip())
                    elif isinstance(v, list):
                        tokens.update(str(x).strip() for x in v)
                else:
                    walk(v)
        elif isinstance(node, list):
            for item in node:
                walk(item)
    walk(data)
for token in list(tokens):
    if "@" in token:
        tokens.add(token.lower())
# only tokens long enough to be a name or an address, never a single initial
for token in sorted(t for t in tokens if len(t) >= 6):
    print(token)
PY
)"

[ -n "$TOKENS" ] || { printf 'people-guard[1]{state}: "the registries name nobody — nothing to check"\n'; exit 0; }

LIST="$(mktemp)"; printf '%s\n' "$TOKENS" > "$LIST"
cleanup() { rm -f "$LIST"; }
trap cleanup EXIT

if [ "$CMD" = "--scan" ]; then
  SCOPE=("$ROOT")
else
  SCOPE=("$ROOT/FEATURES.md" "$ROOT/README.md" "$ROOT/docs" "$ROOT/RULES" "$ROOT/.agents" "$ROOT/bin" "$ROOT/config")
fi

hits="$(grep -rInF -f "$LIST" "${SCOPE[@]}" \
  --include='*.md' --include='*.sh' --include='*.py' --include='*.ts' --include='*.yaml' --include='*.yml' --include='*.json' \
  2>/dev/null | grep -v '/node_modules/' | grep -v '/\.yggdrasil/' | grep -v 'people-guard.sh' | head -20 || true)"

if [ -n "$hits" ]; then
  printf 'people-guard[%s]{file,line}\n' "$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  printf '%s\n' "$hits" | sed -E 's/^([^:]+:[0-9]+):.*/  "\1"/' | head -20
  printf 'people-guard: a person from the registries is in the public tree — a name or an address there\n' >&2
  printf '  is personal data, and a clone may outlive any correction (Rule 04/26)\n' >&2
  exit 1
fi
printf 'people-guard[1]{gate,result}:\n  "%s","clean — no person from the registries is in the tree"\n' "$CMD"
exit 0
