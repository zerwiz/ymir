#!/usr/bin/env bash
# hooks-chain.sh <hook> [args…] — run the repository's own hooks after the kit's, never instead of them.
#
# The targets, in order: the folder recorded in `git config collab.hooks.previous` when the kit was seated
# (a previous core.hooksPath, or .git/hooks), then every folder in project.yaml hooks.chain. A relative
# folder is read from this checkout's top. Standard input is handed to every target (pre-push needs it).
# A target that is the kit's own .githooks is skipped, and a hook that calls back into the kit while the kit
# is already running it is not run twice (KIT_HOOK_ACTIVE).
#
# Exit: the first non-zero exit of a target, else 0.
set -euo pipefail
hook="${1:?hook name}"; shift
root="$(git rev-parse --show-toplevel)"
cd "$root"
ours="$(realpath -m "$root/.githooks")"

targets=()
prev="$(git config --get collab.hooks.previous || true)"
[ -n "$prev" ] && targets+=("$prev")
if [ -f scripts/kit.py ]; then
  while IFS= read -r t; do [ -n "$t" ] && targets+=("$t"); done < <(python3 scripts/kit.py config get hooks.chain 2>/dev/null || true)
fi
[ "${#targets[@]}" -gt 0 ] || exit 0

input=""
case "$hook" in pre-push|post-rewrite|pre-receive|reference-transaction) input="$(cat)";; esac

rc=0
for t in "${targets[@]}"; do
  case "$t" in /*) dir="$t" ;; *) dir="$root/$t" ;; esac
  [ "$(realpath -m "$dir")" = "$ours" ] && continue
  h="$dir/$hook"
  [ -f "$h" ] && [ -x "$h" ] || continue
  if [ -n "$input" ]; then
    printf '%s\n' "$input" | "$h" "$@" || { rc=$?; printf '%s: the repository'"'"'s own hook %s refused\n' "$hook" "$h" >&2; break; }
  else
    "$h" "$@" </dev/null || { rc=$?; printf '%s: the repository'"'"'s own hook %s refused\n' "$hook" "$h" >&2; break; }
  fi
done
exit "$rc"
