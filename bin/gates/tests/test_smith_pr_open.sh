#!/usr/bin/env bash
# test_smith_pr_open.sh — a direct-PR smith may open its PR and never merge it; an empty PR URL
# is a failure (2026-11-12). gh is a declared stub on PATH, only inside this test.
ROOT="$(git rev-parse --show-toplevel)"
fail=0
t() { if [ "$1" = "$2" ]; then echo "PASS: $3"; else echo "FAIL: $3 (want=$1 got=$2)"; fail=1; fi; }
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
printf '#!/usr/bin/env bash\ncase "$1 $2" in "pr create") [ -n "${STUB_URL-}" ] && echo "$STUB_URL"; exit "${STUB_RC:-0}" ;; esac\necho "ran: $*"\n' >"$d/gh"
chmod +x "$d/gh"
smith() { env PATH="$ROOT/bin/forge/smith-bin:$d:$PATH" YMIR_SMITH=helm-roads "$@" 2>&1; }

smith env -u YMIR_SMITH_PR gh pr create --fill >/dev/null; t 1 "$?" "a smith without the direct-PR word is refused pr create"
out=$(STUB_URL=https://github.com/o/r/pull/9 smith env YMIR_SMITH_PR=direct gh pr create --fill); rc=$?
t 0 "$rc" "a direct-PR smith may pr create"; t https://github.com/o/r/pull/9 "$out" "pr create prints the PR URL"
smith env YMIR_SMITH_PR=direct gh pr merge 9 >/dev/null; t 1 "$?" "a direct-PR smith is still refused pr merge"
smith env YMIR_SMITH_PR=direct gh pr close 9 >/dev/null; t 1 "$?" "a direct-PR smith is still refused pr close"

# pr-open.sh: an empty URL or a failed gh is an error, never a printed blank
body="$d/body.md"; printf 'body\n' >"$body"
args=(--role ship --house h --fleet f --errand e --authority a --proves p --title t --body-file "$body")
out=$(cd "$ROOT" && PATH="$d:$PATH" STUB_URL= bash bin/forge/pr-open.sh "${args[@]}" 2>&1); t 1 "$?" "pr-open fails on an empty URL"
out=$(cd "$ROOT" && PATH="$d:$PATH" STUB_URL=https://github.com/o/r/pull/3 bash bin/forge/pr-open.sh "${args[@]}" 2>&1)
t https://github.com/o/r/pull/3 "$out" "pr-open prints the URL when gh gave one"
printf 'MERGE WITH A MERGE COMMIT — batch\n\nrest\n' >"$body"
out=$(cd "$ROOT" && bash bin/forge/pr-open.sh "${args[@]}" --dry-run 2>&1 | head -1)
t "MERGE WITH A MERGE COMMIT — batch" "$out" "the merge-commit banner is the PR's first line"
exit $fail
