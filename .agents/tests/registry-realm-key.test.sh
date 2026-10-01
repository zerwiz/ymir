#!/usr/bin/env bash
# registry-realm-key.test.sh — a project row names its realm, and the OLD key still
# answers BY NAME. The ward of plan 62 item 6: `workspace:` is renamed to `realm:`
# in every reader, but a registry written before the rename must never break
# silently — it must resolve AND say that it used the deprecated key.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PG="$ROOT/bin/project-git.sh"
LIB="$ROOT/bin/registry-lib.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
REG="$TMP/projects.yaml"
cat >"$REG" <<'YAML'
projects:
  - id: newkey
    realm: marketing
    git: { host: github.com, owner: zerwiz, repo: nk, remote: origin, default_branch: main, auth: gh }
  - id: bothkeys
    realm: personal
    workspace: work
    git: { host: github.com, owner: zerwiz, repo: bk, remote: origin, default_branch: main, auth: gh }
  - id: oldkey
    workspace: work
    git: { host: github.com, owner: zerwiz, repo: ok, remote: origin, default_branch: main, auth: gh }
YAML

run() { PROJECTS_YAML="$REG" bash "$PG" "$@" 2>&1; }

# 1. the new key resolves, silently — no warning is noise
out="$(run newkey --field realm)"
printf '%s' "$out" | grep -qx 'marketing' && ok "realm: resolves to the realm" || bad "realm: read '$out'"
printf '%s' "$out" | grep -q 'deprecated-registry-key' && bad "realm: warned about nothing" || ok "realm: does not warn"

# 2. the deprecated key STILL RESOLVES, and names itself
out="$(run oldkey --field realm)"
printf '%s' "$out" | grep -qx 'work' && ok "workspace: alias still resolves" || bad "workspace: alias broke: '$out'"
printf '%s' "$out" | grep -q 'deprecated-registry-key' || bad "workspace: alias resolved without naming the old key"
printf '%s' "$out" | grep -q 'row "oldkey"' || bad "the warning does not name the row: $out"
ok "workspace: alias warns, by name, and names the row"

# 3. a row carrying both keys reads the NEW key and stays quiet
out="$(run bothkeys --field realm)"
printf '%s' "$out" | grep -qx 'personal' && ok "both keys -> realm: wins" || bad "both keys read '$out'"
printf '%s' "$out" | grep -q 'deprecated-registry-key' && bad "both keys warned" || ok "both keys are silent (the row is correct)"

# 4. the block itself is still printed — a reader that prints nothing is not a reader
out="$(run oldkey)"
printf '%s' "$out" | grep -q 'project\[1\]{id,host,owner,repo,remote,default_branch,auth,machine,company,realm}' \
  && ok "the row header names realm" || bad "row header still names the old field: $out"
printf '%s' "$out" | grep -q '"oldkey","github.com","zerwiz","ok"' && ok "the block prints" || bad "the block does not print: $out"

# 5. --field workspace remains an accepted alias, and says what it is
out="$(run oldkey --field workspace)"
printf '%s' "$out" | grep -qx 'work' && ok "--field workspace still resolves" || bad "--field workspace broke: '$out'"
printf '%s' "$out" | grep -q 'deprecated-field' || bad "--field workspace did not name itself"

# 6. the ward: which rows are still on the old key
out="$( . "$LIB"; registry_deprecated_rows "$REG" )"
[ "$out" = "$(printf 'oldkey\twork')" ] && ok "the ward lists exactly the old-key row" || bad "the ward listed '$out'"

# 7. the templates teach the new key and document the alias
grep -qE '^#?\s*realm:' "$ROOT/registry/projects.yaml.example" && ok "projects.yaml.example teaches realm:" || bad "the template still teaches the old key"
grep -q 'workspace:' "$ROOT/registry/projects.yaml.example" && ok "the template documents the deprecated key" || bad "the template does not mention the alias"

[ "$fail" -eq 0 ] || { printf 'registry-realm-key: FAIL\n' >&2; exit 1; }
printf 'registry-realm-key: PASS\n'