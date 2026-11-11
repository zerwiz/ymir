#!/usr/bin/env bash
# test_collab.sh — the proofs for bin/collab (Vingólf). No network, no server: fixtures only.
#
#   bash bin/collab/tests/test_collab.sh
set -uo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
ok(){ pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
no(){ fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# ---- 1 · init installs the shelf into a bare repository -----------------------------------------
repo="$tmp/project"; mkdir -p "$repo"; git -C "$repo" init -q; printf '{}' > "$repo/package.json"
if bash "$_d/init.sh" "$repo" --from testhand >/dev/null 2>&1; then ok "init installs"; else no "init installs"; fi
for f in handoff/README.md handoff/TEMPLATE.md handoff/CURRENT.md handoff/check.py handoff/check.sh; do
  [ -e "$repo/$f" ] && ok "init wrote $f" || no "init wrote $f"
done
ls "$repo"/handoff/log/*.md >/dev/null 2>&1 && ok "init wrote the first baton in log/" || no "init wrote the first baton in log/"

# ---- 2 · it checks a repository that already has a baton, and never overwrites a stray file ------
before="$(md5sum "$repo/handoff/CURRENT.md" | cut -d' ' -f1)"
bash "$_d/init.sh" "$repo" >/dev/null 2>&1 && ok "a second init checks instead of rewriting" || no "a second init checks instead of rewriting"
after="$(md5sum "$repo/handoff/CURRENT.md" | cut -d' ' -f1)"
[ "$before" = "$after" ] && ok "the baton is untouched by a second init" || no "the baton is untouched by a second init"

stray="$tmp/stray"; mkdir -p "$stray/handoff"; printf 'mine\n' > "$stray/handoff/README.md"
bash "$_d/init.sh" "$stray" >/dev/null 2>&1 && no "init refuses to overwrite a stray file" || ok "init refuses to overwrite a stray file"
[ "$(cat "$stray/handoff/README.md")" = "mine" ] && ok "the stray file is left as it was" || no "the stray file is left as it was"

# ---- 3 · the check refuses an incomplete baton ---------------------------------------------------
printf '# baton\n\n**Date:** 2026-01-01\n\n## 1 · Where we are\n' > "$repo/handoff/CURRENT.md"
bash "$_d/init.sh" "$repo" --check >/dev/null 2>&1 && no "an incomplete baton fails" || ok "an incomplete baton fails"

# ---- 4 · the check passes a complete, fresh one --------------------------------------------------
stamp="$(date -u +%Y-%m-%d)"
{ printf '# Handoff — a → b\n\n**Date:** %s\n**Branch:** `main` · **Commit:** `abc1234` · **PR:** none\n' "$stamp"
  printf '**Deployed:** not deployed\n\n'
  printf '## 1 · Where we are\nx\n## 2 · What is done\nx\n## 3 · What is next\nx\n'
  printf '## 4 · What is blocked, and on whom\nx\n## 5 · How to verify the current state\nx\n'
  printf '## 6 · Read first\nx\n## 7 · Traps\nx\n'; } > "$repo/handoff/CURRENT.md"
bash "$_d/init.sh" "$repo" --check >/dev/null 2>&1 && ok "a complete baton passes" || no "a complete baton passes"

# ---- 5 · who, from a captured measurement --------------------------------------------------------
register="$tmp/collab.yaml"
cat > "$register" <<'YAML'
host: fixture
people:
  - id: a
    name: A Person
    rung: L3
    accounts: {gate: a, plane: a@example.com, forge: aforge}
  - id: b
    name: B Person
    rung: L0
    accounts: {gate: b}
  - id: c
    name: C Person
    rung: L2
    accounts: {trello: c@example.com}
YAML
cat > "$tmp/measured.json" <<'JSON'
{"state": "ok", "house_ips": ["85.76.107.74"],
 "gate": {"state": "ok", "users": ["a", "b"], "emails": {"a": "a@example.com", "b": ""},
          "logins": {"a": {"ok": 2, "first": "2026-10-23 13:21:00", "last": "2026-10-23 13:21:00", "ips": ["127.0.0.1", "85.76.107.74"]}},
          "totp": 0, "webauthn": 0},
 "plane": {"state": "ok", "users": [{"email": "a@example.com", "last_login": "2026-10-23 13:21:50", "active": true}], "members": []},
 "affine": {"state": "ok", "users": []},
 "forge": {"state": "ok", "users": [{"name": "aforge", "email": "x", "created": "2026-10-01", "last_login": "2026-10-01", "admin": false, "active": true, "keys": 0}]},
 "shell": {"state": "ok", "accounts": []}}
JSON
out="$(python3 "$_d/who.py" --register "$register" --from "$tmp/measured.json" 2>&1)"
printf '%s' "$out" | grep -q 'A Person","L3","2026-10-23 (house+loopback)"' && ok "who labels a house sign-in as house+loopback" || no "who labels a house sign-in"
printf '%s' "$out" | grep -q '"remote_sign_ins","none recorded"' && ok "who reports no remote sign-in" || no "who reports no remote sign-in"
printf '%s' "$out" | grep -q 'B Person","L0","no sign-in"' && ok "who reports a gate account with no sign-in" || no "who reports no sign-in"
printf '%s' "$out" | grep -q 'B Person has no email on file' && ok "who names a missing email as a gap" || no "who names a missing email"
printf '%s' "$out" | grep -q 'C Person","L2".*"elsewhere (trello)"' && ok "who says elsewhere for a surface it cannot measure" || no "who says elsewhere"

# ---- 6 · the letter renders and never sends ------------------------------------------------------
if bash "$_d/letter.sh" --to a@example.com --person "A Person" --dry-run >/dev/null 2>&1; then
  ok "letter renders"
else no "letter renders"; fi
grep -qs 'args=(draft' "$_d/letter.sh" && ! grep -qs 'args=(send' "$_d/letter.sh" \
  && ok "the letter door only drafts" || no "the letter door only drafts"
grep -qs '{{name}}' "$_d/letters/collaboration-files.md" && ok "the template carries its placeholders" || no "the template carries its placeholders"

# ---- 7 · ship refuses an empty path ---------------------------------------------------------------
bash "$_d/ship.sh" --repo "$repo" --branch b1 --message m --path nope.txt >/dev/null 2>&1 \
  && no "ship refuses an empty path" || ok "ship refuses an empty path"


# ---- 8 · the kit's template shelf is the Bragi skill's, byte for byte (RULES/52, kit RULES/20) ------
_root="$(cd "$_d/../.." && pwd)"
if diff -rq "$_root/.agents/skills/bragi-documents/assets/templates" "$_d/kit/docs/templates" >/dev/null 2>&1; then
  ok "the kit's templates match the bragi-documents skill"
else no "the kit's templates match the bragi-documents skill — copy assets/templates/ into kit/docs/templates/"; fi
[ -f "$_d/kit/RULES/20-documents-are-for-people.md" ] && ok "the kit carries RULES/20" || no "the kit carries RULES/20"

# ---- 9 · a push of only the baton reaches main; code beside it does not (kit RULES/17, 2026-11-11) ---
_h="$(mktemp -d)"
git init -q --bare "$_h/remote.git"
git init -q -b main "$_h/w" && (
  cd "$_h/w" && git config user.email t@example.invalid && git config user.name t
  mkdir -p handoff .githooks && cp "$_d/kit/.githooks/pre-push" .githooks/pre-push && chmod +x .githooks/pre-push
  echo one > handoff/CURRENT.md && echo code > app.txt && git add -A && git commit -qm "first commit of the fixture"
  git remote add origin "$_h/remote.git" && git push -q --no-verify origin main 2>/dev/null
  git config core.hooksPath .githooks
)
( cd "$_h/w" && echo two > handoff/CURRENT.md && git commit -qam "the baton for the next hand" && git push -q origin main ) >/dev/null 2>&1 \
  && ok "a push carrying only handoff/ reaches main" || no "a push carrying only handoff/ reaches main"
( cd "$_h/w" && echo three > handoff/CURRENT.md && echo more >> app.txt && git commit -qam "the baton and a code change" && git push -q origin main ) >/dev/null 2>&1 \
  && no "a push with code beside the baton is refused at main" || ok "a push with code beside the baton is refused at main"
rm -rf "$_h"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
