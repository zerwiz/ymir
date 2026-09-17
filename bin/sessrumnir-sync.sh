#!/usr/bin/env bash
# sessrumnir-sync.sh — pull a new pi-desktop release into the Sessrúmnir fork
# without losing the Ymir delta. The law: upstream owns everything except the
# Ymir-owned files; the branding rides on top and is re-applied by a true
# 3-way git merge, never by clobbering.
#
#   bin/sessrumnir-sync.sh                       # sync to the version pinned in fork/PIN
#   bin/sessrumnir-sync.sh <tag-or-commit>       # sync to an explicit upstream ref
#   bin/sessrumnir-sync.sh --check [<ref>]       # dry-run: what would change (no writes)
#   bin/sessrumnir-sync.sh --regen <ref>         # after hand-resolving conflicts: renumber PIN,
#                                                # regenerate mods.patch, run the gate
#
# How a sync works (the fork-rebase):
#   base   = pristine upstream tree at PIN        (what the fork was cut from)
#   ours   = the branded fork as it sits now      (base + Ymir delta)
#   theirs = pristine upstream tree at <ref>      (whatever the Allfather pulls)
#   git merge base←ours + base←theirs  →  a true 3-way merge. Conflicts are
#   left in the working tree for Brokk to resolve, never auto-resolved, never
#   half-applied. Bare changes from upstream land; our branding survives where
#   upstream did not touch the same lines; collisions are surfaced as markers.
#
# Exits 0 on a clean, gated sync; 2 on merge conflicts left for the operator;
# 1 on any hard failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(dirname "$_ya")/bin/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
app_dir sessrumnir APP_SESSRUMNIR || APP_SESSRUMNIR=""

APP="$APP_SESSRUMNIR"
FORK="$APP/fork"
UPSTREAM_REPO="${SESSRUMNIR_UPSTREAM:-https://github.com/zerwiz/pi-desktop.git}"
OWNED_JSON="$FORK/owned.json"
MODS_PATCH="$FORK/mods.patch"
PIN_FILE="$FORK/PIN"

MODE="sync"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --regen) MODE="regen"; shift ;;
    *) break ;;
  esac
done
TARGET="${1:-}"

fail() { echo "✗ $*" >&2; exit 1; }
step() { printf '\n▸ %s\n' "$*"; }

# ─── Pin reading ──────────────────────────────────────────────────────────────
read_pin() {
  [[ -f "$PIN_FILE" ]] || fail "no PIN at $PIN_FILE — a full sync never happened yet"
  local line hash
  while IFS= read -r line; do
    hash="${line%%#*}"
    hash="${hash// /}"
    [[ "$hash" =~ ^[0-9a-f]{7,40}$ ]] && { echo "$hash"; return; }
  done < "$PIN_FILE"
  fail "PIN file at $PIN_FILE holds no commit hash"
}

# ─── Named sets from owned.json ───────────────────────────────────────────────
[[ -f "$OWNED_JSON" ]] || fail "owned.json missing — the fork contract is gone ($OWNED_JSON)"
OWNED_FILES=()
while IFS= read -r f; do OWNED_FILES+=("$f"); done < <(jq -r '.files[]' "$OWNED_JSON" 2>/dev/null || fail "owned.json unreadable — is jq installed?")
GENERATED_PATHS=()
while IFS= read -r f; do GENERATED_PATHS+=("$f"); done < <(jq -r '.generated[]' "$OWNED_JSON" 2>/dev/null)

step "Sessrúmnir fork sync ($MODE)"
echo "  upstream : $UPSTREAM_REPO"
echo "  target   : ${TARGET:-$(read_pin)}"

# ─── Fetch upstream ───────────────────────────────────────────────────────────
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
step "cloning upstream into $SCRATCH/up"
git clone "$UPSTREAM_REPO" "$SCRATCH/up" >/dev/null 2>&1 || fail "clone failed for $UPSTREAM_REPO"

resolve_ref() { # <ref-or-empty> -> commit hash
  local ref="${1:-}"; ref="${ref:-HEAD}"
  ( cd "$SCRATCH/up" && git rev-parse --verify "$ref^{commit}" ) 2>/dev/null \
    || fail "ref not found upstream: $ref"
}

THEIRS_COMMIT="$(resolve_ref "$TARGET")"
THEIRS_SHORT="${THEIRS_COMMIT:0:10}"
echo "  upstream HEAD: $THEIRS_SHORT ($(cd "$SCRATCH/up" && git log -1 --format=%s "$THEIRS_COMMIT"))"

# ─── Materialise the three trees ──────────────────────────────────────────────
pin_commit="$(read_pin 2>/dev/null || echo "")"
BASE_COMMIT="$pin_commit"
if [[ -z "$BASE_COMMIT" ]]; then
  echo "  (no PIN yet — first sync; base := empty tree, every upstream file arrives)"
  IS_FIRST_SYNC=1
  BASE_COMMIT=""
fi

checkout_tree() { # <dir> <commit-or-empty>
  local dir="$1" commit="$2"
  if [[ -z "$commit" ]]; then
    mkdir -p "$dir"
  else
    git -C "$SCRATCH/up" worktree add --detach "$dir" "$commit" >/dev/null 2>&1 \
      || fail "cannot materialise $commit"
  fi
}

checkout_tree "$SCRATCH/base" "$BASE_COMMIT"
checkout_tree "$SCRATCH/theirs" "$THEIRS_COMMIT"
ours=$APP  # the branded fork is the working tree itself

# ─── Exclude map shared by every copy ─────────────────────────────────────────
copy_tree() { # <src> <dst>   (rsync: refresh files, delete upstream removals)
  local src="$1" dst="$2" ex=()
  for f in "${GENERATED_PATHS[@]}" ".git" "fork"; do ex+=(--exclude="$f"); done
  for f in "${OWNED_FILES[@]}"; do ex+=(--exclude="$f"); done
  rsync -a --delete "${ex[@]}" "$src/" "$dst/"
}

# ─── --check: show what a sync would change ───────────────────────────────────
if [[ "$MODE" == "check" ]]; then
  step "--check: what a sync to $THEIRS_SHORT would change (no writes)"
  local ex=()
  for f in "${GENERATED_PATHS[@]}" ".git" "fork"; do ex+=(--exclude="$f"); done
  for f in "${OWNED_FILES[@]}"; do ex+=(--exclude="$f"); done
  rsync -a --delete --dry-run "${ex[@]}" "$SCRATCH/theirs/" "$APP/" 2>/dev/null \
    | grep -E "^deleting|^>f" | head -60
  echo
  echo "  owned files and fork/ are never touched; upstream deletions are respected;"
  echo "  branding rides in fork/mods.patch and is re-merged, not clobbered."
  exit 0
fi

# ─── --regen: after hand-resolving conflicts ──────────────────────────────────
if [[ "$MODE" == "regen" ]]; then
  [[ -n "$TARGET" ]] || fail "--regen needs the upstream ref you synced to"
  step "regenerating delta from resolved tree (base=$THEIRS_SHORT)"
  # pristine base at target vs current (resolved) app tree, owned files excluded.
  mkdir -p "$SCRATCH/out" && copy_tree "$SCRATCH/theirs" "$SCRATCH/out/base" 
  mkdir -p "$SCRATCH/out/app" && copy_tree "$APP" "$SCRATCH/out/app"
  ( cd "$SCRATCH/out" && diff -ruN base app > "$SCRATCH/mods.patch" 2>/dev/null || true )
  [[ -s "$SCRATCH/mods.patch" ]] || fail "no delta between pristine $THEIRS_SHORT and app — nothing vendored?"
  cp "$SCRATCH/mods.patch" "$MODS_PATCH"
  cat > "$PIN_FILE" <<EOF
# Upstream pi-desktop commit currently vendored into apps/sessrumnir
$THEIRS_COMMIT   # $(cd "$SCRATCH/up" && git log -1 --format=%s "$THEIRS_COMMIT")
$(cd "$SCRATCH/up" && git describe --tags "$THEIRS_COMMIT" 2>/dev/null || echo "(no tag at $THEIRS_SHORT)")
EOF
  echo "  PIN → $THEIRS_SHORT; mods.patch regenerated ($(wc -l < "$SCRATCH/mods.patch") lines)"
  step "gate: install, typecheck, lint, build"
  ( cd "$APP" && npm install --no-audit --no-fund >/dev/null 2>&1 ) || fail "npm install failed"
  ( cd "$APP" && npm run typecheck 2>&1 | tail -5 ) || fail "typecheck failed"
  ( cd "$APP" && npm run lint 2>&1 | tail -8 ) || fail "lint failed"
  ( cd "$APP" && npm run build 2>&1 | tail -5 ) || fail "build failed"
  echo
  echo "✓ sync sealed — Sessrúmnir now vendors $THEIRS_SHORT"
  echo "  next: stage the tree, review, open a PR (human seals merges)."
  exit 0
fi

# ─── Sync: the fork-rebase ────────────────────────────────────────────────────
step "materialising the three trees"
checkout_tree "$SCRATCH/ours.tmp" "$BASE_COMMIT" 2>/dev/null || true
copy_tree "$APP" "$SCRATCH/ours.tmp"  # ours = branded fork as it sits (owned files ride along)

step "building the merge in a scratch repo"
MERGE="$SCRATCH/merge"
git init -q "$MERGE"
cd "$MERGE"
git config user.name "Brokk" >/dev/null 2>&1 || true
git config user.email "brokk@ymir.local" >/dev/null 2>&1 || true
export GIT_AUTHOR_NAME="Brokk" GIT_AUTHOR_EMAIL="brokk@ymir.local"
export GIT_COMMITTER_NAME="Brokk" GIT_COMMITTER_EMAIL="brokk@ymir.local"

# base commit (pristine upstream at PIN)
rsync -a --exclude=.git "$SCRATCH/base/" ./
git add -A -f; BASE_T=$(git write-tree); BASE_C=$(git commit-tree "$BASE_T" -m "base")
# clean worktree + index for ours (branded fork, owned+fork excluded by design)
git rm -rf --quiet . 2>/dev/null; git clean -fd >/dev/null 2>&1
rsync -a --exclude=.git "$SCRATCH/ours.tmp/" ./
git add -A -f; OURS_T=$(git write-tree); OURS_C=$(git commit-tree "$OURS_T" -p "$BASE_C" -m "ours")
# clean again for theirs (new upstream)
git rm -rf --quiet . 2>/dev/null; git clean -fd >/dev/null 2>&1
rsync -a --exclude=.git "$SCRATCH/theirs/" ./
git add -A -f; THEIRS_T=$(git write-tree); THEIRS_C=$(git commit-tree "$THEIRS_T" -p "$BASE_C" -m "theirs")
# branches + merge
git update-ref refs/heads/ours "$OURS_C"
git update-ref refs/heads/theirs "$THEIRS_C"
git symbolic-ref HEAD refs/heads/ours
git checkout -f ours >/dev/null 2>&1 || true

step "merging upstream $THEIRS_SHORT into the branded fork (3-way)"
git merge --no-commit --no-ff theirs >merge.log 2>&1 || true
grep -E "CONFLICT|Automatic merge failed" merge.log || true

# conflicts?
CONFLICTED="$(git diff --name-only --diff-filter=U)"
if [[ -n "$CONFLICTED" ]]; then
  echo
  echo "⚠ merge conflicts — resolving in apps/sessrumnir before sealing:" >&2
  echo "$CONFLICTED" | sed 's/^/    /' >&2
  # lay the merged tree (conflict markers included) into the fork so resolution
  # happens in the real working tree; owned files and fork/ are never touched.
  copy_tree "$MERGE" "$APP"
  echo >&2
  echo "  the merged tree with conflict markers is now the working tree under" >&2
  echo "  apps/sessrumnir. Branding is ours; upstream-only change is theirs. A" >&2
  echo "  deleted file either side re-added by upstream means: decide. Present" >&2
  echo "  the changed files and resolve by hand (owned files carry the Ymir text)." >&2
  echo "  When done, re-run the merge and seal with:" >&2
  echo '    bin/sessrumnir-sync.sh --regen '"$THEIRS_SHORT" >&2
  exit 2
fi

step "sealing sync (no conflicts)"
copy_tree "$MERGE" "$APP"   # merged tree back into the fork (owned + fork/ excluded separately)
step "writing PIN"
cat > "$PIN_FILE" <<EOF
# Upstream pi-desktop commit currently vendored into apps/sessrumnir
$THEIRS_COMMIT   # $(cd "$SCRATCH/up" && git log -1 --format=%s "$THEIRS_COMMIT")
$(cd "$SCRATCH/up" && git describe --tags "$THEIRS_COMMIT" 2>/dev/null || echo "(no tag at $THEIRS_SHORT)")
EOF
echo "  pinned $THEIRS_SHORT"

step "regenerating mods.patch (pristine $THEIRS_SHORT → branded fork)"
mkdir -p "$SCRATCH/out/base" "$SCRATCH/out/app"
copy_tree "$SCRATCH/theirs" "$SCRATCH/out/base"
copy_tree "$APP" "$SCRATCH/out/app"
( cd "$SCRATCH/out" && diff -ruN base app > "$SCRATCH/mods.patch" 2>/dev/null || true )
cp "$SCRATCH/mods.patch" "$MODS_PATCH"

step "gate: install, typecheck, lint, build"
( cd "$APP" && npm install --no-audit --no-fund >/dev/null 2>&1 ) || fail "npm install failed"
( cd "$APP" && npm run typecheck 2>&1 | tail -5 ) || fail "typecheck failed"
( cd "$APP" && npm run lint 2>&1 | tail -8 ) || fail "lint failed"
( cd "$APP" && npm run build 2>&1 | tail -5 ) || fail "build failed"

echo
echo "✓ sync complete — Sessrúmnir now vendors $THEIRS_SHORT"
echo "  next: review the diff, then open a PR (human seals merges)."