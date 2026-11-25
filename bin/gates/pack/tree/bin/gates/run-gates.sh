#!/usr/bin/env bash
# run-gates.sh — the one door to this repository's gates. The hooks and CI both call it, so a commit, a push
# and a pull request meet the same judges. It is part of Ymir's gate pack (see VENDORED): never edit it here.
#
#   bin/gates/run-gates.sh staged               the commit about to be made (pre-commit)
#   bin/gates/run-gates.sh range <base> <head>  what a push or a pull request adds
#   bin/gates/run-gates.sh tree                 every tracked file, and gitleaks over the whole history (CI)
#
# The judges (each is Ymir's own ward, vendored byte for byte):
#   secret     secret-guard.sh (key shapes, private env files) · gitleaks through secret-scan.sh
#   personal   public-guard.py (names the operator declared, private addresses, personal mailboxes, fleet
#              hosts) · private-guard.py (the home's private paths and protected material)
#   identity   identity-guard.sh (a commit's author and committer mailbox) · pr-identity-guard.sh (CI, on a PR)
#   vault      vault-guard.sh (a file byte-identical to one in the open vault) ·
#              secrets-plaintext-guard.sh (a home secrets shelf committed in the clear)
#
# THE DENY LIST NEVER LEAVES THE HOME. On a seat the wards read the operator's words, machine names and mail
# domains from the home ($YMIR_HOME, resolved by bin/vault/hoard-lib.sh), and a machine named as a host is then
# a refusal. CI has no home and is never given the list: there the shapes are judged (keys, private addresses,
# personal mailboxes, a house identity), and the words are judged by the hooks and the home's own audit.
#
# Exit: 0 every judge clean · 1 a judge refused · 2 usage.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
G="$ROOT/bin/gates/guards"
cd "$ROOT"

# Is the home's deny list readable here? Only then are the operator's words and machines judged.
home_has_list() {
  local h="${YMIR_HOME:-}"
  if [ -z "$h" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
    h="$(bash -c '. "$1" 2>/dev/null; ymir_home_root h 2>/dev/null; printf %s "${h:-}"' _ "$ROOT/bin/vault/hoard-lib.sh")"
  fi
  [ -n "$h" ] && [ -r "$h/hodd/security/operator-words.txt" ]
}
STRICT=()
if home_has_list; then
  [ "${YMIR_PUBLIC_GUARD_STRICT:-1}" = 1 ] && STRICT=(--strict-names)
else
  printf 'run-gates: no home deny list here — judging shapes only (keys, addresses, mailboxes); the words are judged on a seat\n' >&2
fi
# This repository is not a home: the plaintext ward judges THIS tree for a secrets shelf that strayed here.
export YMIR_SECRETS_GUARD_ROOT="$ROOT"

verb="${1:-}"
failed=()

# THE VENDORED FILES ARE JUDGED IN YMIR, NOT HERE, BY THE PRIVATE GUARD. private-guard.py refuses a home path, a
# vault file name or a secret shape in anything that leaves; the wards that hunt those shapes must name them. Here
# they are proven byte-identical to Ymir's by bin/gates/vendor-sync.sh, and every other gate still judges them.
# Only the files VENDORED lists (under files: and pack:) are skipped, by exact path.
mapfile -t VENDORED_FILES < <(awk '/^(files|pack):/ {on=1; next} /^[^ #]/ {on=0} on && /^  [^ ]/ {print $1}' "$ROOT/VENDORED" 2>/dev/null)
not_vendored() {  # reads paths on stdin, prints those VENDORED does not list
  local f v skip
  while IFS= read -r f; do
    skip=0
    for v in "${VENDORED_FILES[@]}"; do [ "$f" = "$v" ] && { skip=1; break; }; done
    [ "$skip" = 0 ] && printf '%s\n' "$f"
  done
}
# THE PRIVATE GUARD JUDGES WHAT A CHANGE ADDS. private-guard.py is a surface ward (a mail, a post, a page that
# leaves); it has no notion of a line a repository already carried, and an app repository that left Ymir with its
# history names Ymir's public layout in old comments. So a commit and a pull request are judged on the lines they
# ADD (binding), and the whole-tree run reports what is inherited without refusing it. Each judged file is a copy
# with only its added lines kept and every other line blank, so the line numbers in a finding are the real ones.
private_added() {  # <diff-args...> -- <file...>   exit 1 when an added line is refused
  local args=() files=() f seen=0 work rc=0 out
  for f in "$@"; do if [ "$seen" = 0 ]; then [ "$f" = -- ] && seen=1 || args+=("$f"); else files+=("$f"); fi; done
  [ "${#files[@]}" -gt 0 ] || return 0
  work="$(mktemp -d)"
  for f in "${files[@]}"; do
    mkdir -p "$work/$(dirname "$f")"
    git diff -U0 --no-color "${args[@]}" -- "$f" | python3 -c '
import re, sys
keep, n = {}, 0
for line in sys.stdin:
    m = re.match(r"^@@ -\S+ \+(\d+)(?:,(\d+))? @@", line)
    if m:
        n = int(m.group(1)); continue
    if line.startswith("+++"):
        continue
    if line.startswith("+"):
        keep[n] = line[1:].rstrip("\n"); n += 1
top = max(keep) if keep else 0
sys.stdout.write("".join((keep.get(i, "") + "\n") for i in range(1, top + 1)))
' > "$work/$f"
  done
  out="$(cd "$work" && python3 "$G/private-guard.py" check "${files[@]}" --surface public 2>&1)" || rc=1
  [ -n "$out" ] && printf '%s\n' "$out"
  rm -rf "$work"
  return "$rc"
}
private_tree_advisory() {  # <file...>  never refuses; says how many inherited lines it would name
  local out n
  out="$(python3 "$G/private-guard.py" check "$@" --surface public 2>&1)"
  n="$(printf '%s\n' "$out" | grep -cE ':[0-9]+: ' || true)"
  if [ "${n:-0}" -gt 0 ]; then
    printf 'gate private-guard      inherited: %s line(s) the tree already carried (advisory; a change that adds one is refused):\n' "$n"
    printf '%s\n' "$out" | grep -E ':[0-9]+: ' | head -10 | sed 's/^/  /'
  else
    printf 'gate private-guard      clean\n'
  fi
}
judge() {  # <name> <command...>
  local name="$1"; shift
  if "$@"; then printf 'gate %-18s clean\n' "$name"
  else printf 'gate %-18s REFUSED\n' "$name" >&2; failed+=("$name"); fi
}

gitleaks_present() { command -v "${YMIR_GITLEAKS:-gitleaks}" >/dev/null 2>&1; }
gitleaks_judge() {  # <secret-scan verb>
  if gitleaks_present; then
    YMIR_SECRET_SCAN_CONFIG="$ROOT/.gitleaks.toml" bash "$ROOT/bin/gates/secret-scan.sh" "$1"
  elif [ -n "${CI:-}" ]; then
    printf 'gitleaks is not installed in CI — the scan cannot be skipped there\n' >&2; return 1
  else
    printf 'gate gitleaks           not installed here — CI runs it on every pull request\n'
  fi
}

case "$verb" in
  staged)
    mapfile -t files < <(git diff --cached --name-only --diff-filter=ACM)
    mapfile -t own < <([ "${#files[@]}" -gt 0 ] && printf '%s\n' "${files[@]}" | not_vendored)
    judge secret-guard        bash "$G/secret-guard.sh"
    judge public-guard        python3 "$G/public-guard.py" --staged "${STRICT[@]}"
    [ "${#own[@]}" -gt 0 ] && judge private-guard private_added --cached -- "${own[@]}"
    judge identity-guard      bash "$G/identity-guard.sh" --staged
    judge vault-guard         bash "$G/vault-guard.sh"
    judge secrets-plaintext   bash "$G/secrets-plaintext-guard.sh"
    gitleaks_present && judge gitleaks gitleaks_judge staged
    ;;
  range)
    base="${2:-}"; head="${3:-}"
    [ -n "$base" ] && [ -n "$head" ] || { printf 'error: range needs <base> <head>\n' >&2; exit 2; }
    mapfile -t files < <(git diff --name-only --diff-filter=ACM "$base" "$head")
    mapfile -t own < <([ "${#files[@]}" -gt 0 ] && printf '%s\n' "${files[@]}" | not_vendored)
    judge secret-guard        bash "$G/secret-guard.sh" --range "$base" "$head"
    if [ "${#files[@]}" -gt 0 ]; then
      judge public-guard      python3 "$G/public-guard.py" --added "$base" "${files[@]}" "${STRICT[@]}"
    fi
    [ "${#own[@]}" -gt 0 ] && judge private-guard private_added "$base" "$head" -- "${own[@]}"
    judge identity-guard      bash "$G/identity-guard.sh" --base "$base"
    judge vault-guard         bash "$G/vault-guard.sh" --all
    judge secrets-plaintext   bash "$G/secrets-plaintext-guard.sh" --all
    gitleaks_present && judge gitleaks gitleaks_judge dir
    ;;
  tree)
    mapfile -t files < <(git ls-files)
    mapfile -t own < <(printf '%s\n' "${files[@]}" | not_vendored)
    judge secret-guard        bash "$G/secret-guard.sh" --all
    judge public-guard        python3 "$G/public-guard.py" --tree "${STRICT[@]}"
    private_tree_advisory "${own[@]}"
    judge vault-guard         bash "$G/vault-guard.sh" --all
    judge secrets-plaintext   bash "$G/secrets-plaintext-guard.sh" --all
    judge gitleaks            gitleaks_judge tree
    ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

if [ "${#failed[@]}" -gt 0 ]; then
  printf 'run-gates: refused by %s — read the lines above; the fix is in the change, never in the gate\n' "${failed[*]}" >&2
  exit 1
fi
printf 'run-gates: %s clean\n' "$verb"
