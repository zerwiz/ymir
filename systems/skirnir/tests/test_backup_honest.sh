#!/usr/bin/env bash
# backup.sh is honest: a refused commit exits non-zero, names the refusal, and leaves nothing of its own
# staged; another job's staged file is neither committed nor unstaged.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
h="$t/home"; mkdir -p "$h/state/assistant" "$h/hodd"
export YMIR_HOME="$h"; unset YMIR_HOARD YMIR_STATE_DIR
git -C "$h" init -q; git -C "$h" config user.email t@t; git -C "$h" config user.name t
git -C "$h" config core.hooksPath .git/hooks
printf 'base\n' > "$h/base"; git -C "$h" add base; git -C "$h" commit -qm base
printf '{"q":1}\n' > "$h/state/assistant/digest.jsonl"
printf 'in flight\n' > "$h/other"; git -C "$h" add other
shelf=hodd/saves/assistant
run() { bash "$root/systems/skirnir/services/backup.sh" --push 2>&1; }
die() { echo "FAIL: $1"; printf '%s\n' "${out:-}"; exit 1; }

printf '#!/bin/sh\necho "guard: BLOCKED — not today" >&2\nexit 1\n' > "$h/.git/hooks/pre-commit"
chmod +x "$h/.git/hooks/pre-commit"
before="$(git -C "$h" ls-files -s)"
out="$(run)"; rc=$?
[ "$rc" -ne 0 ] || die "a refused commit exited 0"
case "$out" in *"commit refused: guard: BLOCKED — not today"*) ;; *) die "the refusal is not named" ;; esac
case "$out" in *"commit made"*|*"committed to"*) die "claimed a commit" ;; esac
[ "$(git -C "$h" ls-files -s)" = "$before" ] || die "the index changed: $(git -C "$h" diff --cached --name-only)"

# what was staged under the shelf BEFORE this run stays staged as it was
mkdir -p "$h/$shelf/old"; printf 'earlier\n' > "$h/$shelf/old/a b"; git -C "$h" add "$shelf/old/a b"
printf 'changed since\n' > "$h/$shelf/old/a b"
before="$(git -C "$h" ls-files -s)"
out="$(run)" && die "a refused commit exited 0 (second run)"
[ "$(git -C "$h" ls-files -s)" = "$before" ] || die "earlier staging was not restored"

# allowed: it commits its shelf only; with no remote the push line is true
rm "$h/.git/hooks/pre-commit"
out="$(run)" || die "an allowed commit failed"
case "$out" in *"commit made, push failed"*) ;; *) die "the push failure is not said" ;; esac
git -C "$h" show --name-only --format= HEAD | grep -qv "^\"\?$shelf/" && die "the commit carries a foreign path"
[ "$(git -C "$h" diff --cached --name-only)" = other ] || die "the other job's staged file moved"
echo "PASS backup.sh fails on a refused commit, restores the index, and commits only its shelf"
