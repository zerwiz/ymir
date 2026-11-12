#!/usr/bin/env bash
# keeps-user-changes.sh — an update keeps what the user changed in the first agent (plan 275, 2026-11-12):
# her soul keeps the user's own words around the house's managed block, and her config keeps a tool server, a toolset
# and a setting the user added, while the house's own parts are refreshed. Runs on temp files only.
set -u
HOUSE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/house/house.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
export YMIR_HOME="$T/home"; mkdir -p "$T/home/hodd/identity"
soul() { python3 "$HOUSE" soul --name Nanna --role "the one who answers" "$@"; }

# a soul still as the old full render becomes the managed block, once
soul --full > "$T/full.md"
soul > "$T/a.md"
grep -q 'house:begin' "$T/a.md" && ok "an untouched soul becomes the house's managed block" || bad "no managed block: $(head -2 "$T/a.md")"

# the user writes her own line; a setup keeps it and refreshes the block
printf 'She always answers in Swedish when the operator writes Swedish.\n\n%s' "$(cat "$T/a.md")" > "$T/edited.md"
soul --existing "$T/edited.md" > "$T/b.md"
grep -q 'always answers in Swedish' "$T/b.md" && ok "the user's own line survives a setup" || bad "user line lost"
[ "$(grep -c 'house:begin' "$T/b.md")" = 1 ] && ok "the house block appears once" || bad "block duplicated"
soul --existing "$T/b.md" > "$T/c.md"
cmp -s "$T/b.md" "$T/c.md" && ok "a second setup changes nothing" || bad "not idempotent"

# the config: the user's additions are kept, the house's parts win
cat > "$T/existing.yaml" <<'EOF'
model:
  default: "the-model-the-user-chose"
mcp_servers:
  ymir: {command: old}
  my-notes: {command: /usr/local/bin/notes-mcp}
platform_toolsets:
  api_server: [web, my-toolset]
my_setting: true
EOF
cat > "$T/rendered.yaml" <<'EOF'
mcp_servers:
  ymir: {command: python3, args: [ymir-mcp.py]}
  well: {url: https://example.invalid/well}
platform_toolsets:
  api_server: [web, terminal, file]
EOF
python3 "$HOUSE" merge --existing "$T/existing.yaml" --rendered "$T/rendered.yaml" > "$T/merged.yaml"
python3 - "$T/merged.yaml" <<'PY' && ok "the config keeps the user's model, tool server, toolset and setting, and takes the house's parts" || bad "merge: $(cat "$T/merged.yaml")"
import sys, yaml
m = yaml.safe_load(open(sys.argv[1]))
assert m['model']['default'] == 'the-model-the-user-chose'
assert m['mcp_servers']['my-notes']['command'] == '/usr/local/bin/notes-mcp'
assert m['mcp_servers']['ymir']['command'] == 'python3'      # the house's door is refreshed
assert 'well' in m['mcp_servers']
assert m['platform_toolsets']['api_server'][:3] == ['web', 'terminal', 'file'] and 'my-toolset' in m['platform_toolsets']['api_server']
assert m['my_setting'] is True
PY

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
