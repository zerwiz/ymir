#!/usr/bin/env bash
# Unit tests for bin/gates/guards/defaults-guard.sh — the ward that keeps one machine's paths
# out of the tree that every machine clones.
#
# The defect this test exists for: `state` was tracked as a symlink to
# $HOME_SEAT/Documents/ymirhome/state, and tools/mill/worker.sh carried
# three absolute /home/<seat> paths. Both shipped to every clone. The ward reads
# the INDEX (a symlink's content is its target), so a worktree grep can never see
# that class of drift — hence the third pass.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/bin/gates/guards/defaults-guard.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Pin the ward's own state so it never touches the operator's real home.
export YMIR_STATE_DIR="$TMP/state"

# ── a scratch tree the ward can root at, so a planted link never touches ours ──
seed_repo() {
  local repo="$1"
  mkdir -p "$repo/bin" "$repo/.agents" "$repo/tools" "$repo/scripts" "$repo/src/ymir_runtime"
  cp "$GUARD" "$repo/bin/gates/guards/defaults-guard.sh"
  printf '#!/usr/bin/env bash\nhoard_state_dir() { printf -v "$1" %%s "${YMIR_STATE_DIR:-/nonexistent}"; }\n' \
    >"$repo/bin/vault/hoard-lib.sh"
  chmod +x "$repo/bin/gates/guards/defaults-guard.sh"
  git -C "$repo" init -q 2>/dev/null
  git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" commit -qm seed >/dev/null 2>&1
}

# ── 1. the mended tree is clean ───────────────────────────────────────────────
if bash "$GUARD" check >/dev/null 2>&1; then
  ok "the mended tree passes the ward"
else
  bad "the mended tree FAILS the ward"
  bash "$GUARD" check 2>&1 | grep -v '^  "none"' | head -5 >&2
fi

# ── 2. the defect that shipped: an absolute symlink in the index ─────────────
HOME_SEAT="${HOME_SEAT:-$HOME/Documents/ymirhome}"   # the seat the house uses
export HOME_SEAT
repo="$TMP/repo-link"
seed_repo "$repo"
ln -s $HOME_SEAT/Documents/ymirhome/state "$repo/state"
git -C "$repo" add -f state >/dev/null 2>&1
out="$(bash "$repo/bin/gates/guards/defaults-guard.sh" check 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'absolute symlink ships a machine path'; then
  ok "an absolute tracked symlink is refused"
else
  bad "an absolute tracked symlink was NOT refused (rc=$rc)"
  printf '%s\n' "$out" | head -4 >&2
fi

# a RELATIVE in-tree link is the law's own shape (Rule 02 harness links)
rm -f "$repo/state"
mkdir -p "$repo/.agents/agents"
printf 'x\n' >"$repo/.agents/agents/brokk.md"
ln -s ../.agents/agents "$repo/.agents/rel-link"
git -C "$repo" add -A >/dev/null 2>&1
if bash "$repo/bin/gates/guards/defaults-guard.sh" check >/dev/null 2>&1; then
  ok "a relative in-tree symlink is allowed"
else
  bad "a relative in-tree symlink was wrongly refused"
  bash "$repo/bin/gates/guards/defaults-guard.sh" check 2>&1 | grep -v '^  "none"' | head -3 >&2
fi

# ── 3. a guessed seat home in an executable line, anywhere in scope ───────────
# The fixture must plant a GUESSED path, not a variable: `$HOME_SEAT/mill/…` names a
# variable and is a legitimate shape, so the ward correctly did not refuse it — this
# suite was asserting behaviour the ward never had, over a fixture that did not plant
# what its own comment claimed (the sibling failure in this same file, HOME_SEAT
# unbound, was written in the same sitting). A guess looks like a path that DECIDES
# where the home is: /home/<someone>/Documents/ymirhome/… — and that is what lands here.
repo2="$TMP/repo-lit"
seed_repo "$repo2"
printf '#!/usr/bin/env bash\ncat /home/someone/Documents/ymirhome/hodd/data/fleet.json\n' >"$repo2/tools/mill-worker.sh"
git -C "$repo2" add -A >/dev/null 2>&1
out="$(bash "$repo2/bin/gates/guards/defaults-guard.sh" check 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'a home guessed'; then
  ok "a guessed seat path in tools/ is refused"
else
  bad "a guessed seat path in tools/ was NOT refused (rc=$rc)"
  printf '%s\n' "$out" | head -4 >&2
fi

# ── 4. a COMMENT quoting a path is prose, not a default ───────────────────────
printf '#!/usr/bin/env bash\n# the home is ~/Documents/ymirhome\n# $HOME_SEAT/mill/legacy\n' >"$repo2/tools/mill-worker.sh"
git -C "$repo2" add -A >/dev/null 2>&1
if bash "$repo2/bin/gates/guards/defaults-guard.sh" check >/dev/null 2>&1; then
  ok "a quoted path in a comment is not a finding"
else
  bad "a quoted path in a comment WAS a finding"
fi

# ── 5. the shipped state symlink cannot return ────────────────────────────────
if git -C "$ROOT" ls-files -s state | grep -q .; then
  bad "state is TRACKED again — the shipped defect is back"
else
  ok "state is not tracked"
fi
if git -C "$ROOT" check-ignore -q state 2>/dev/null; then
  ok "state is ignored — the ignore rule covers the path itself"
else
  bad "state is NOT ignored (a symlink named state escapes state/*)"
fi

# ── 6. one definition of the default, in code and in the ward's own scope ─────
n="$(git -C "$ROOT" grep -lE 'DEFAULT_HOME = "~/Documents/ymirhome"' -- src/ bin/ 2>/dev/null | wc -l)"
if [ "$n" -eq 1 ]; then
  ok "the home default is defined in exactly one file"
else
  bad "the home default is defined in $n files — it must be 1"
fi

# ── 7. the second shipped defect: mill worker carries no machine path ─────────
if grep -qE '/home/[A-Za-z0-9_.-]+/|/Users/[A-Za-z0-9_.-]+/' "$ROOT/tools/mill/worker.sh" 2>/dev/null; then
  bad "tools/mill/worker.sh still carries a machine-local path"
  grep -nE '/home/[A-Za-z0-9_.-]+/|/Users/[A-Za-z0-9_.-]+/' "$ROOT/tools/mill/worker.sh" | head -3 >&2
else
  ok "tools/mill/worker.sh carries no machine-local path"
fi

# ── 8. the mended worker resolves its paths from env, and they still work ─────
if grep -q 'MILL_HOME="${MILL_HOME:-$HOME/mill}"' "$ROOT/tools/mill/worker.sh" \
   && grep -q 'YMIR_ROOT="${YMIR_ROOT:-' "$ROOT/tools/mill/worker.sh"; then
  ok "the mill worker resolves MILL_HOME and YMIR_ROOT from env"
else
  bad "the mill worker does not resolve its paths from env"
fi
bash -n "$ROOT/tools/mill/worker.sh" 2>/dev/null && ok "the mill worker parses" || bad "the mill worker does not parse"

[ "$fail" -eq 0 ] || exit 1
exit 0