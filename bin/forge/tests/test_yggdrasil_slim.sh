#!/usr/bin/env bash
# test_yggdrasil_slim.sh — the slimmer worktree is opt-in, and the default is unchanged.
#
# A repository that vendors a large tracked folder (a `base/`, a `vendor/`) paid for it again in
# every worktree. `yggdrasil.sh create --skip <dir>` and `--slim` (the project's `.worktree-slim`)
# leave it out by sparse-checkout. This proves:
#
#   · the default create still checks the folder out (and still excludes .pi/extensions)
#   · --skip <dir> leaves the folder out, keeps everything else, and the tree reads clean
#   · --slim reads .worktree-slim (comments and blanks ignored)
#   · --slim without .worktree-slim refuses and leaves no worktree or branch behind
#   · an unsafe --skip (`..`) refuses and leaves nothing behind
#
# Usage: test_yggdrasil_slim.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
YGG="$ROOT/bin/forge/yggdrasil.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_GLOBAL="$TMP/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global init.defaultBranch main >/dev/null 2>&1
# The worktree road may record into a ledger; fence it away from the real one.
export XDG_STATE_HOME="$TMP/state" YMIR_WORKTREE_LEDGER="$TMP/ledger"

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

R="$TMP/repo"
mkdir -p "$R/base/deep" "$R/src" "$R/.pi/extensions/x" "$R/vendor"
echo big > "$R/base/deep/file"; echo code > "$R/src/main"; echo ext > "$R/.pi/extensions/x/index.ts"
echo v > "$R/vendor/lib"; echo top > "$R/README"
git -C "$R" init -q && git -C "$R" add -A && git -C "$R" commit -qm init

# 1. default unchanged
out=$("$YGG" create plain --repo "$R" 2>&1) || bad "default create failed: $out"
if [ -f "$R/.yggdrasil/plain/base/deep/file" ] && [ ! -e "$R/.yggdrasil/plain/.pi/extensions" ]; then ok "default keeps base/ and drops .pi/extensions"; else bad "default layout changed"; fi
case "$out" in *slim\[*) bad "default printed a slim row" ;; *) ok "default output carries no slim row" ;; esac

# 2. --skip base
out=$("$YGG" create thin --repo "$R" --skip base 2>&1) || bad "--skip create failed: $out"
W="$R/.yggdrasil/thin"
if [ ! -e "$W/base" ] && [ -f "$W/src/main" ] && [ -f "$W/vendor/lib" ] && [ -f "$W/README" ]; then ok "--skip base leaves base/ out and keeps the rest"; else bad "--skip layout wrong"; fi
[ -z "$(git -C "$W" status --porcelain)" ] && ok "--skip tree reads clean (no phantom deletions)" || bad "--skip tree is dirty"
case "$out" in *'"base","not checked out (--skip)"'*) ok "--skip names what it skipped" ;; *) bad "--skip did not report: $out" ;; esac

# 3. --slim reads .worktree-slim
printf '# vendored trees\nbase\n\nvendor/   # also this\n' > "$R/.worktree-slim"
git -C "$R" add .worktree-slim && git -C "$R" commit -qm slim
out=$("$YGG" create slim --repo "$R" --slim 2>&1) || bad "--slim create failed: $out"
W="$R/.yggdrasil/slim"
if [ ! -e "$W/base" ] && [ ! -e "$W/vendor" ] && [ -f "$W/src/main" ]; then ok "--slim skips every listed folder"; else bad "--slim layout wrong"; fi

# 4. --slim without the file refuses and leaves nothing
R2="$TMP/repo2"; mkdir -p "$R2/base"; echo x > "$R2/base/f"
git -C "$R2" init -q && git -C "$R2" add -A && git -C "$R2" commit -qm init
if "$YGG" create nolist --repo "$R2" --slim >/dev/null 2>&1; then bad "--slim without .worktree-slim succeeded"; else ok "--slim without .worktree-slim refuses"; fi
if [ ! -e "$R2/.yggdrasil/nolist" ] && ! git -C "$R2" show-ref --quiet refs/heads/yggdrasil/nolist; then ok "the refusal leaves no worktree or branch"; else bad "the refusal left debris"; fi

# 5. unsafe skip
if "$YGG" create evil --repo "$R2" --skip ../etc >/dev/null 2>&1; then bad "unsafe --skip accepted"; else ok "unsafe --skip refused"; fi
if [ ! -e "$R2/.yggdrasil/evil" ] && ! git -C "$R2" show-ref --quiet refs/heads/yggdrasil/evil; then ok "unsafe refusal leaves nothing"; else bad "unsafe refusal left debris"; fi

exit $fail
