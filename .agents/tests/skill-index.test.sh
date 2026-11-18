#!/usr/bin/env bash
# Unit tests for the skill index loop — bin/agents/skill-index.sh +
# bin/agents/skill-find.sh.
#
# The defect this test exists for: a skills inventory existed and was DEAD. No
# trigger generated it, no tool read it, and the finder's home-shelf resolver
# sourced a hoard-lib.sh that does not exist at its own path — so HOMESKILLS fell
# back to the SHIP shelf and three upstream layouts were invisible. ~130 skills
# existed; the finder reached 3.
#
# So the properties under test are the ones that keep the loop ALIVE:
#   1. the walk is GENERIC — a SKILL.md nested at any depth is found, no pack
#      known by name;
#   2. the index is written where the finder reads it, and the finder returns the
#      skill by name;
#   3. --check passes on a fresh index and FAILS when a skill is absent from it
#      (the index cannot be silently dead).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IDX="$ROOT/bin/agents/skill-index.sh"
FIND="$ROOT/bin/agents/skill-find.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# A throwaway HOME for every case: the root skill, the store and the box live under
# $HOME / $XDG_DATA_HOME, and a test must never write the operator's real ones.
export HOME="$TMP/fakehome" XDG_DATA_HOME="$TMP/fakehome/.local/share"
unset YMIR_SKILL_STORE YMIR_BOX_SKILLS
mkdir -p "$HOME"

# A scratch repo the tools can root at, with the two doors and a stub resolver.
# `_root()` walks up to `.pi` + `RULES`, so both must exist or the tool roots at
# the wrong place (the very class of bug this test guards).
REPO="$TMP/repo"
mkdir -p "$REPO/bin/agents" "$REPO/bin/vault" "$REPO/.pi" "$REPO/RULES" \
         "$REPO/.agents/skills" "$REPO/.agents/skills-local"
cp "$IDX" "$REPO/bin/agents/skill-index.sh"
cp "$FIND" "$REPO/bin/agents/skill-find.sh"
chmod +x "$REPO/bin/agents/"*.sh
printf '#!/usr/bin/env bash\nymir_home_root() { printf -v "$1" %%s "${YMIR_HOME:-/nonexistent}"; }\n' \
  > "$REPO/bin/vault/hoard-lib.sh"

# The home, pinned to the scratch tree so the operator's real home is never touched.
export YMIR_HOME="$TMP/home"
# A skill at THREE levels of nesting — the layout the finder was blind to.
mkdir -p "$YMIR_HOME/.agents/skills/mypack/deep/nested" "$YMIR_HOME/hodd/docs"
cat > "$YMIR_HOME/.agents/skills/mypack/deep/nested/SKILL.md" <<'SK'
---
name: deep-skill
description: A skill buried three levels down, found only by a generic walk.
---
# Deep skill
SK

# ── 1. the walk is generic and the index is written where the finder reads it ──
bash "$IDX" >/dev/null 2>&1
INDEX_FILE="$YMIR_HOME/.agents/skills/skills.yaml"
if [ -s "$INDEX_FILE" ] && grep -q 'name: "deep-skill"' "$INDEX_FILE"; then
  ok "a SKILL.md nested three levels deep is indexed"
else
  bad "the index missed a nested SKILL.md (walk is not generic)"
fi

# ── 2. the finder resolves it by name, from the index ────────────────────────
got="$(bash "$FIND" --where deep-skill 2>/dev/null)"
if [ "$got" = "$YMIR_HOME/.agents/skills/mypack/deep/nested/SKILL.md" ]; then
  ok "--where resolves the nested skill from the index"
else
  bad "--where deep-skill returned '${got:-<empty>}'"
fi

# ── 3a. --check is green on a fresh index ────────────────────────────────────
if bash "$IDX" --check >/dev/null 2>&1; then
  ok "--check passes on a fresh index"
else
  bad "--check failed on a fresh index"
fi

# ── 3b. --check FAILS when the index cannot see a skill present on disk ──────
# Corrupt the index so the freshly-added skill is absent, then add another.
# A stale/incomplete index must be a LOUD failure, never a silent zero.
printf '# deliberately emptied\nversion: 1\ntotal: 0\nskills:\n' > "$INDEX_FILE"
mkdir -p "$YMIR_HOME/.agents/skills/other"
cat > "$YMIR_HOME/.agents/skills/other/SKILL.md" <<'SK'
---
name: other-skill
description: Another skill, to prove the check notices an incomplete index.
---
SK
if bash "$IDX" --check >/dev/null 2>&1; then
  bad "--check passed an index missing a skill — it can go dead silently"
else
  ok "--check fails loudly when the index is incomplete"
fi

# ── 3c. and a finder refresh heals it without a human ────────────────────────
bash "$FIND" --where other-skill >/dev/null 2>&1
if bash "$IDX" --check >/dev/null 2>&1 && grep -q 'name: "other-skill"' "$INDEX_FILE"; then
  ok "the finder refreshed a stale index by itself"
else
  bad "the finder did not heal the index"
fi

# ── 4. a worktree must not fight the canonical index ─────────────────────────
# The index is ONE shared file in the home. A Yggdrasil worktree walking its own
# shipped skills would rewrite it and call every canonical skill INCOMPLETE.
( set -e
  export YMIR_HOME="$TMP/home2"
  REPO2="$TMP/gitrepo"
  mkdir -p "$REPO2/bin/agents" "$REPO2/bin/vault" "$REPO2/.pi" "$REPO2/RULES" \
           "$REPO2/.agents/skills/shipped" "$YMIR_HOME/.agents/skills" "$YMIR_HOME/hodd/docs"
  cp "$IDX" "$REPO2/bin/agents/skill-index.sh"; chmod +x "$REPO2/bin/agents/"*.sh
  printf '#!/usr/bin/env bash\nymir_home_root() { printf -v "$1" %%s "${YMIR_HOME:-/nonexistent}"; }\n' \
    > "$REPO2/bin/vault/hoard-lib.sh"
  printf -- '---\nname: shipped-skill\ndescription: A canonical shipped skill.\n---\n' \
    > "$REPO2/.agents/skills/shipped/SKILL.md"
  git -C "$REPO2" init -q; git -C "$REPO2" config user.email t@t; git -C "$REPO2" config user.name t
  git -C "$REPO2" add -A >/dev/null; git -C "$REPO2" commit -qm seed
  ( cd "$REPO2" && bash bin/agents/skill-index.sh >/dev/null 2>&1 )
  git -C "$REPO2" worktree add -q --detach "$TMP/wt" HEAD 2>/dev/null || true
  if ( cd "$TMP/wt" && bash bin/agents/skill-index.sh --check >/dev/null 2>&1 ); then
    printf 'ok - %s\n' "a worktree does not spuriously stale the shared index"
  else
    printf 'not ok - %s\n' "--check from a worktree called the canonical index stale" >&2
    exit 7
  fi
) || fail=1

# ── 5. the index carries NO machine path (Rule 25 — it must be portable) ─────
# The index is written shelf-RELATIVE, so a copy on another machine anchors to its
# OWN roots instead of naming paths that do not exist there. This is the fault of
# 2026-10-18: a committed index carried 192 absolute /home/<seat>/… paths into a
# home that syncs to a second machine, where every one of them was a lie.
if grep -q 'path: "/' "$INDEX_FILE"; then
  bad "the index wrote an absolute machine path (not portable)"
else
  ok "the index stores shelf-relative paths only — no machine path"
fi

# ── 6. plan 248 P3b: ONE ymir skill in every root, ONE unscanned store ───────
mkdir -p "$HOME/.claude" "$HOME/.agents/skills/boxy" "$HOME/.pi/agent/skills" "$REPO/.agents/skills/clash" \
         "$YMIR_HOME/.agents/skills/clash"
printf -- '---\nname: boxy\ndescription: A box skill left in a scanned shelf.\n---\nbody word: fjallagrasa\n' \
  > "$HOME/.agents/skills/boxy/SKILL.md"
printf 'asset\n' > "$HOME/.agents/skills/boxy/notes.txt"
ln -s "$HOME/.agents/skills/boxy" "$HOME/.pi/agent/skills/boxy"
printf -- '---\nname: clash\ndescription: The shipped one.\n---\n' > "$REPO/.agents/skills/clash/SKILL.md"
printf -- '---\nname: clash\ndescription: The home one.\n---\n' > "$YMIR_HOME/.agents/skills/clash/SKILL.md"
ROOTSK="$HOME/.agents/skills/ymir/SKILL.md"
# the scratch repo's copies, so the shipped shelf is $REPO/.agents/skills, not this checkout's
RIDX="$REPO/bin/agents/skill-index.sh"; RFIND="$REPO/bin/agents/skill-find.sh"
STORE_DIR="$XDG_DATA_HOME/ymir/skills"

if bash "$RIDX" --root-check 2>/dev/null | grep -q '^box: .*boxy'; then
  ok "--root-check names a box skill sitting in a scanned shelf"
else
  bad "--root-check did not name the box skill in ~/.agents/skills"
fi

bash "$RIDX" --adopt-box >/dev/null 2>&1
if [ ! -e "$HOME/.agents/skills/boxy" ] && [ -f "$XDG_DATA_HOME/ymir/box-skills/boxy/SKILL.md" ] \
   && [ -f "$XDG_DATA_HOME/ymir/box-skills/boxy/notes.txt" ] && [ ! -L "$HOME/.pi/agent/skills/boxy" ]; then
  ok "--adopt-box carries a box skill intact out of the scanned shelf and drops the dangling pi link"
else
  bad "--adopt-box did not move the box skill whole"
fi

bash "$RIDX" --root >/dev/null 2>&1
n_root="$(find "$HOME/.agents/skills" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
if [ "$n_root" = 1 ] && [ -f "$ROOTSK" ] && [ "$(readlink "$HOME/.claude/skills/ymir")" = "$HOME/.agents/skills/ymir" ]; then
  ok "each root lists exactly one Ymir skill (~/.agents/skills/ymir; Claude by link)"
else
  bad "the roots do not carry exactly one ymir skill (found $n_root in ~/.agents/skills)"
fi

unres=0; npaths=0
while IFS= read -r pth; do
  npaths=$((npaths+1)); [ -r "$pth" ] || { unres=$((unres+1)); printf '  unresolved %s\n' "$pth" >&2; }
done < <(grep -o '`/[^`]*SKILL.md`' "$ROOTSK" | tr -d '`')
if [ "$npaths" -ge 4 ] && [ "$unres" = 0 ]; then
  ok "the index resolves every path ($npaths) through the store"
else
  bad "the index has $unres unresolved of $npaths paths"
fi

if [ "$(readlink "$STORE_DIR/clash")" = "$REPO/.agents/skills/clash" ]; then
  ok "a shipped skill wins a name clash in the store"
else
  bad "the store linked clash to $(readlink "$STORE_DIR/clash") — the shipped shelf must win"
fi

# the front matter must PARSE as YAML — pi drops a skill whose front matter does not, silently
if python3 -c 'import sys,yaml; t=open(sys.argv[1]).read().split("---")[1]; d=yaml.safe_load(t); sys.exit(0 if d.get("name")=="ymir" and d.get("description") else 1)' "$ROOTSK" 2>/dev/null; then
  ok "the root skill's front matter parses as YAML (name ymir, a description)"
else
  bad "the root skill's front matter does not parse — a harness would drop it"
fi
desc_bytes="$(sed -n '2,3p' "$ROOTSK" | wc -c | tr -d ' ')"
if [ "$desc_bytes" -le 220 ] && grep -q '^description: .\{20,\}' "$ROOTSK"; then
  ok "the per-turn cost is one name and one description line ($desc_bytes bytes)"
else
  bad "the root skill's front matter is $desc_bytes bytes — it must stay ~200"
fi

before="$(stat -c %Y "$ROOTSK" 2>/dev/null || stat -f %m "$ROOTSK")"
sleep 1; bash "$RIDX" --root >/dev/null 2>&1
after="$(stat -c %Y "$ROOTSK" 2>/dev/null || stat -f %m "$ROOTSK")"
if bash "$RIDX" --root-check >/dev/null 2>&1 && [ "$before" = "$after" ]; then
  ok "--root-check is green and a second --root writes nothing (idempotent by content)"
else
  bad "the root is not stable across a rebuild"
fi

if YMIR_SKILL_STORE="$HOME/.agents/skills/store" bash "$RIDX" --root >/dev/null 2>&1; then
  bad "a store inside a scanned directory was accepted"
else
  [ ! -e "$HOME/.agents/skills/store" ] && ok "a store inside a scanned directory is refused" \
    || bad "a refused store still left a directory in the scanned shelf"
fi

if bash "$RFIND" fjallagrasa 2>/dev/null | grep -q 'boxy'; then
  ok "skill-find searches full bodies and reaches the box shelf"
else
  bad "skill-find did not find a word that lives only in a box skill's body"
fi

mkdir -p "$YMIR_HOME/.agents/skills/nodesc"; printf '# no front matter\n' > "$YMIR_HOME/.agents/skills/nodesc/SKILL.md"
if bash "$RFIND" --check 2>&1 >/dev/null | grep -q 'nodesc/SKILL.md'; then
  ok "skill-find --check names an unfindable skill"
else
  bad "skill-find --check did not name a skill with no description"
fi

# the root contract carries the one sentence, and the check reads the same words
if grep -qF 'load the \`ymir\` skill and follow its index' "$ROOT/bin/agents/seat-identity.sh" \
   && grep -qF 'load the `ymir` skill and follow its index' "$ROOT/bin/seat/seat-surface.sh"; then
  ok "the seat render sends every craft to the ymir skill, and seat-surface --check looks for it"
else
  bad "the render sentence and the seat-surface check disagree"
fi

printf '\n%s\n' "----------------------------------------"
if [ "$fail" = 0 ]; then printf 'skill-index.test.sh: all passed\n'; else printf 'skill-index.test.sh: FAILED\n' >&2; fi
exit "$fail"
