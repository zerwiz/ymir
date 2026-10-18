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

printf '\n%s\n' "----------------------------------------"
if [ "$fail" = 0 ]; then printf 'skill-index.test.sh: all passed\n'; else printf 'skill-index.test.sh: FAILED\n' >&2; fi
exit "$fail"
