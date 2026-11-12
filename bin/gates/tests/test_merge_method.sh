#!/usr/bin/env bash
# test_merge_method.sh — the merge flag follows the PR's kind (RULES/08, batch road).
ROOT="$(git rev-parse --show-toplevel)"
. "$ROOT/bin/forge/merge-method.sh"
fail=0
t() { local want="$1" got="$2" name="$3"; if [ "$got" = "$want" ]; then echo "PASS: $name"; else echo "FAIL: $name want=$want got=$got"; fail=1; fi; }
t --merge  "$(merge_flag_for yggdrasil/gather-20261112-020726 '')" "gather head branch"
t --merge  "$(merge_flag_for gather/local-sweep '')" "gather/ head branch"
t --merge  "$(merge_flag_for some/branch 'One batch, gathered by `bin/forge/gather.sh` (RULES/08)')" "gathered body"
t --squash "$(merge_flag_for eindri/fix-thing 'a plain fix')" "ordinary PR"
t --squash "$(merge_flag_for '' '')" "empty"
# merge_flag_for_pr through a stubbed gh (a declared fixture, on PATH only inside this test)
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
printf '#!/usr/bin/env bash\n[ -n "$GH_STUB_JSON" ] || exit 1\necho "$GH_STUB_JSON"\n' >"$d/gh"; chmod +x "$d/gh"
t --merge  "$(PATH="$d:$PATH" GH_STUB_JSON='{"headRefName":"yggdrasil/gather-1","body":"x"}' merge_flag_for_pr 5)" "pr: gather head via gh"
t --squash "$(PATH="$d:$PATH" GH_STUB_JSON='{"headRefName":"eindri/x","body":null}' merge_flag_for_pr 5)" "pr: ordinary via gh, null body"
t --squash "$(PATH="$d:$PATH" GH_STUB_JSON='' merge_flag_for_pr 5)" "pr: gh failure falls back to squash"
t --merge  "$(merge_flag_for some/branch 'x' 'gather: 3 errands in one batch (b)')" "gather title"
t --merge  "$(merge_flag_for some/branch 'MERGE WITH A MERGE COMMIT — batch' '')" "merge-commit banner body"
t --squash "$(merge_flag_for eindri/x 'a plain fix' 'fix: gather the thing')" "a title that merely mentions gather"
t --merge  "$(PATH="$d:$PATH" GH_STUB_JSON='{"headRefName":"eindri/x","body":"b","title":"gather: 2 errands"}' merge_flag_for_pr 5)" "pr: gather title via gh"
PATH="$d:$PATH" GH_STUB_JSON='{"headRefName":"yggdrasil/gather-1","body":"x","title":"gather: 1"}' refuse_squash_of_gather 5 --squash >/dev/null 2>&1
t 1 "$?" "squashing a gather PR is refused"
PATH="$d:$PATH" GH_STUB_JSON='{"headRefName":"yggdrasil/gather-1","body":"x","title":"gather: 1"}' refuse_squash_of_gather 5 --merge >/dev/null 2>&1
t 0 "$?" "merging a gather PR with a merge commit is allowed"
PATH="$d:$PATH" GH_STUB_JSON='{"headRefName":"eindri/x","body":"x","title":"fix"}' refuse_squash_of_gather 5 --squash >/dev/null 2>&1
t 0 "$?" "squashing an ordinary PR is allowed"
exit $fail
