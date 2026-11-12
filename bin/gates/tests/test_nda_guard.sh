#!/usr/bin/env bash
# test_nda_guard.sh — the NDA matcher, the git hooks' commands and the Claude write hook, over a FAKE home.
# Only invented names are used here (Zorblax, Quuxmere, Plinthco, Vantablack Works). No real name is ever in this file.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
G="$ROOT/bin/gates/guards/nda-guard.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

# ── a fake home ──────────────────────────────────────────────────────────────
H="$T/home"; mkdir -p "$H/hodd/identity" "$H/svartalfaheim/plinthco" "$H/svartalfaheim/.inbox"
cat >"$H/hodd/identity/companies.yaml" <<'Y'
companies:
  - {id: zorblax, name: "Zorblax Holdings"}
Y
cat >"$H/hodd/identity/clients.yaml" <<'Y'
clients:
  - {id: quuxmere, name: Quuxmere}
Y
cat >"$H/hodd/identity/projects.yaml" <<'Y'
projects:
  - {id: vantablack-works, name: "Vantablack Works", posture: private, repo: Co/vantablack, realm: work}
  - {id: openthing, name: Openthing, posture: public}
  - {id: ymir-sidecar, name: "Ymir Sidecar", posture: private}
Y
cat >"$H/hodd/identity/confidential.yaml" <<'Y'
nda:
  - Runeglimmer
Y
export YMIR_HOME="$H"

scan() { printf '%s\n' "$1" >"$T/f.txt"; python3 "$G" tree "$T/f.txt" 2>&1; }

# ── matching rules ───────────────────────────────────────────────────────────
scan "we ship for Zorblax Holdings" | grep -q 'protected company' && ok "a company name is refused" || bad "company"
scan "client QUUXMERE signed" | grep -q 'protected client' && ok "case-insensitive client" || bad "client case"
scan "see vantablack-works" | grep -q 'protected project' && ok "a project id is refused" || bad "project"
scan "the Runeglimmer deal" | grep -q 'nda-list' && ok "the hand-written nda: list is read" || bad "nda list"
scan "Quuxmeres of the field" | grep -q protected && bad "whole word only (suffix)" || ok "whole word only: a longer word is not a hit"
scan "xQuuxmere" | grep -q protected && bad "whole word (prefix)" || ok "whole word only: a prefix is not a hit"
scan "openthing and ymir-sidecar are ours" | grep -q protected && bad "public/ymir projects" || ok "a public project and Ymir's own are not protected"
scan "work in the plinthco realm" | grep -q 'realm name "plinthco"' && ok "a realm directory is protected" || bad "realm"
scan "an .inbox shelf" | grep -q protected && bad "dot realm" || ok "a dot-directory is not a realm"
scan "just ordinary prose" | grep -q protected && bad "clean" || ok "clean text passes"
# the line, never the rest of it
out="$(scan 'secret sentence about Quuxmere and more')"
printf '%s' "$out" | grep -q 'secret sentence' && bad "echoes the line" || ok "the refusal never echoes the line, only the name"
printf '%s' "$out" | grep -qE ':1: protected' && ok "the refusal names the line" || bad "line number"

# ── the allow file ───────────────────────────────────────────────────────────
mkdir -p "$T/repo/config" "$T/repo/bin/gates/guards"
cp "$ROOT/bin/gates/guards/ndalib.py" "$ROOT/bin/gates/guards/nda-guard.py" "$T/repo/bin/gates/guards/"
printf 'allow:\n  - word: work\n    reason: ordinary English\n  - word: plinthco\n' >"$T/repo/config/nda-allow.yaml"
r="$(cd "$T/repo" && printf 'plinthco and zorblax\n' >f.txt && python3 bin/gates/guards/nda-guard.py tree f.txt 2>&1)"
printf '%s' "$r" | grep -q 'plinthco' && ok "an allow entry with no reason is ignored" || bad "reasonless allow"
printf 'allow:\n  - word: plinthco\n    reason: it is a public house\n' >"$T/repo/config/nda-allow.yaml"
r="$(cd "$T/repo" && python3 bin/gates/guards/nda-guard.py tree f.txt 2>&1)"
printf '%s' "$r" | grep -q 'plinthco' && bad "allow with reason" || ok "an allow entry with a reason lets the word through"
printf '%s' "$r" | grep -qi zorblax && ok "…and the rest are still refused" || bad "rest refused"

# ── no home: loud, never silent ──────────────────────────────────────────────
r="$(YMIR_HOME="$T/nowhere" HOME="$T/nohome" python3 "$G" tree "$T/f.txt" 2>&1)"
printf '%s' "$r" | grep -q UNARMED && ok "no home says UNARMED aloud" || bad "unarmed"

# ── the git hooks, in a throwaway repo ───────────────────────────────────────
R="$T/g"; mkdir -p "$R/bin/gates/guards" "$R/.githooks"
cp "$ROOT/bin/gates/guards/ndalib.py" "$ROOT/bin/gates/guards/nda-guard.py" "$R/bin/gates/guards/"
cp "$ROOT/.githooks/pre-commit" "$ROOT/.githooks/commit-msg" "$R/.githooks/"
( cd "$R" && git init -q . && git config user.email t@t && git config user.name t && git config core.hooksPath .githooks \
  && echo hello >a.txt && git add a.txt && git commit -q -m "first" ) && ok "a clean commit goes through the hooks" || bad "clean commit"
( cd "$R" && echo "contract with Zorblax" >b.txt && git add b.txt && git commit -q -m "add b" ) 2>/dev/null \
  && bad "pre-commit let a name through" || ok "pre-commit refuses a staged name"
( cd "$R" && git reset -q && rm -f b.txt && echo fine >c.txt && git add c.txt && git commit -q -m "notes about Quuxmere" ) 2>/dev/null \
  && bad "commit-msg let a name through" || ok "commit-msg refuses a name in the message"
( cd "$R" && echo x >"zorblax-notes.txt" && git add zorblax-notes.txt && git commit -q -m "path" ) 2>/dev/null \
  && bad "a protected name in a path" || ok "a protected name in a file path is refused"
# the pushed range: a commit made with hooks off is still judged at push
( cd "$R" && git rm -q --cached zorblax-notes.txt 2>/dev/null; rm -f zorblax-notes.txt; echo "Vantablack Works plans" >d.txt && git add d.txt && git -c core.hooksPath=/dev/null commit -q -m "d" )
base="$(cd "$R" && git rev-parse HEAD~1)"; head="$(cd "$R" && git rev-parse HEAD)"
( cd "$R" && printf 'refs/heads/x %s refs/heads/x %s\n' "$head" "$base" | python3 bin/gates/guards/nda-guard.py push ) 2>/dev/null \
  && bad "pre-push let the range through" || ok "pre-push judges the pushed range"

# ── the Claude write hook ────────────────────────────────────────────────────
mkdir -p "$T/ymirtree/RULES" "$T/ymirtree/bin/gates/guards"; cp "$ROOT/bin/gates/guards/ndalib.py" "$T/ymirtree/bin/gates/guards/"
hk() { printf '{"tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2" | python3 "$G" hook; }
hk "$T/ymirtree/docs/n.md" "a note on Zorblax" | grep -q '"deny"' && ok "the hook denies a write into a Ymir tree" || bad "hook deny"
[ -z "$(hk "$T/ymirtree/docs/n.md" "a clean note")" ] && ok "the hook lets a clean write through" || bad "hook clean"
[ -z "$(hk "$H/hodd/note.md" "a note on Zorblax")" ] && ok "a write into the home is allowed" || bad "hook home"
[ -z "$(hk "$T/elsewhere/n.md" "a note on Zorblax")" ] && ok "a write outside any Ymir tree is allowed" || bad "hook elsewhere"

# ── people (plan 272, fault 11): a person is refused like a company is ───────
# Invented people only: Fenwick Ostrander, fostrander, @fen_ostr_chat, roster speaker "Tamsin Quillfeather".
cat >"$H/hodd/identity/collaborators.yaml" <<'Y'
people:
  - id: fenwick
    name: Fenwick Ostrander
    emails: [fostrander@example.test, info@example.test]
    telegram: [fen_ostr_chat]
    github: ostrander-gh
Y
mkdir -p "$H/hodd/data/telegram-rosters"
printf 'chat: -1\nspeakers:\n  - {user: 7, name: "Tamsin Quillfeather", username: tquill_rost}\n' >"$H/hodd/data/telegram-rosters/-1.yaml"
for who in "Fenwick Ostrander" fostrander fen_ostr_chat ostrander-gh "Tamsin Quillfeather" tquill_rost; do
  printf 'a line naming %s here\n' "$who" >"$T/msg.txt"
  python3 "$G" message "$T/msg.txt" 2>&1 | grep -q 'protected person' && ok "a commit message naming a person is refused ($who)" || bad "person refused: $who"
done
printf 'write to info@example.test\n' >"$T/msg.txt"
python3 "$G" message "$T/msg.txt" 2>&1 | grep -q protected && bad "generic mailbox local part" || ok "a generic mailbox local part (info) is not a person"
[ -n "$(hk "$T/ymirtree/docs/n.md" "thanks tquill_rost" | grep '"deny"')" ] && ok "the write hook refuses a roster username" || bad "hook person"
printf 'old line about Fenwick Ostrander\n' >"$T/f.txt"
python3 "$G" tree "$T/f.txt" >/dev/null 2>&1 && ok "a whole-file read counts an old person line as owed, does not refuse it" || bad "tree owed"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
