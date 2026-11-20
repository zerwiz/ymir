#!/usr/bin/env bash
# secret-guard.sh — refuse to commit obvious secrets or private env files.
#
#   bin/gates/guards/secret-guard.sh            # scan the staged change (used as pre-commit)
#   bin/gates/guards/secret-guard.sh --install  # wire it into .git/hooks/pre-commit
#   bin/gates/guards/secret-guard.sh --all      # scan every tracked file once
#   bin/gates/guards/secret-guard.sh --range <base> <head>  # the files a push adds, read at <head>
#
# Exit 1 on any hit, so a commit is blocked before a secret leaves the machine.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

PATTERNS='(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(ghp|gho|ghs|ghr)_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]+|AIza[0-9A-Za-z_-]{35}|(CLOUDFLARE_API_TOKEN|OPENCODE_GO_API_KEY|GITHUB_TOKEN|OPENAI_API_KEY|ANTHROPIC_API_KEY)[[:space:]]*=[[:space:]]*[A-Za-z0-9_./+=-]{8,})'

# Paths deliberately exempt (test fixtures with fake secret-shaped strings),
# one glob per line in .secret-guardignore.
IGNORE="$ROOT/.secret-guardignore"
is_ignored() {
  [ -r "$IGNORE" ] || return 1
  local p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in \#*) continue ;; esac
    case "$1" in $p) return 0 ;; esac
  done <"$IGNORE"
  return 1
}

case "${1:-}" in
  -v|-V|--version) printf '1.0.0\n'; exit 0 ;;
  -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --install)
    # ONE HOME FOR THE HOOK TEXT (2026-11-20). This used to GENERATE a pre-commit body here, and the
    # shipped `.githooks/pre-commit` carried a different one: the generated copy wove the catalogue and
    # ran public/docs/private/vault/confidential-guard plus no-delete-guard, while the shipped file ran
    # the NDA gate, the secret scan and the retired-path gate. Two bodies meant the gate a commit met
    # depended on `core.hooksPath`. Worse, once the install seats the hooks with `core.hooksPath
    # .githooks`, `git rev-parse --git-path hooks` ANSWERS `.githooks` — so this heredoc would have
    # overwritten a TRACKED hook in the working tree. The shipped file is the one pre-commit (it now
    # carries the weaver and the staged wards too); this installer seats THAT file, and seats nothing
    # when the shipped directory is already the hooks directory.
    SRC="$ROOT/.githooks/pre-commit"
    if [ ! -r "$SRC" ]; then
      printf 'error: %s is missing\nhelp: the pre-commit hook has one home and it is that file\n' "$SRC" >&2
      exit 1
    fi
    # `git rev-parse --git-path hooks` resolves the hooks dir for a clone AND for a worktree, where
    # `$ROOT/.git` is a FILE — an installer that assumed a directory could seat no ward at all in the
    # place all the work happens (found 2026-11-03, installing from a worktree), and it honours
    # `core.hooksPath`, which is where a seat's hooks now live.
    hook="$(cd "$ROOT" && git rev-parse --git-path hooks 2>/dev/null || printf '%s/.git/hooks' "$ROOT")"
    case "$hook" in /*) ;; *) hook="$ROOT/$hook" ;; esac   # git may answer absolute or relative
    if [ -d "$hook" ] && [ "$(cd "$hook" && pwd -P)" = "$(cd "$ROOT/.githooks" && pwd -P)" ]; then
      printf 'secret-guard[1]{action,path}:\n  "install",".githooks/pre-commit (core.hooksPath names the shipped hook — nothing to copy)"\n'
      exit 0
    fi
    mkdir -p "$hook" || exit 1
    cp "$SRC" "$hook/pre-commit" && chmod +x "$hook/pre-commit" || exit 1
    printf 'secret-guard[1]{action,path}:\n  "install","%s"\n' "${hook#"$ROOT"/}/pre-commit"
    exit 0 ;;
esac

scan_list() {
  local hit=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    is_ignored "$f" && continue
    # A GUARD CONTAINS THE SHAPES IT LOOKS FOR. The guards shelf is where the patterns live,
    # so moving one made it newly staged and it flagged ITSELF — a false positive produced by a
    # rename. The detection shapes are the work; nothing in here is a credential.
    case "$f" in
      bin/gates/guards/*|bin/backend/fm-vendor-auth-probe.sh) continue ;;
    esac
    case "$f" in
      .env.local|*/.env.local|*.env.local|.env.realm|*/.env.realm)
        printf 'secret-guard: private env file: %s\n' "$f" >&2; hit=1; continue ;;
    esac
    if git -C "$ROOT" show "${SCAN_REV}:$f" 2>/dev/null | sed 's/AKIAIOSFODNN7EXAMPLE//g' | grep -Eq "$PATTERNS"; then
      printf 'secret-guard: possible secret in %s\n' "$f" >&2; hit=1
    fi
  done
  return "$hit"
}

# SCAN_REV is what `git show <rev>:<path>` reads: the index (empty) for a commit, a commit for a range.
SCAN_REV=""
if [ "${1:-}" = "--all" ]; then
  scan_list < <(git -C "$ROOT" ls-files)
elif [ "${1:-}" = "--range" ]; then
  # THE PARKING ROAD (plan 339.1): a parked push is judged by what it ADDS, read from the pushed
  # commit itself — never the working tree, which a crash-survival push may not even match.
  [ -n "${2:-}" ] && [ -n "${3:-}" ] || { printf 'error: --range needs <base> <head>\n' >&2; exit 2; }
  SCAN_REV="$3"
  scan_list < <(git -C "$ROOT" diff --name-only --diff-filter=ACM "$2" "$3")
else
  scan_list < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACM)
fi || { printf 'secret-guard: blocked — remove the secret or move it to a .example file\n' >&2; exit 1; }
exit 0
