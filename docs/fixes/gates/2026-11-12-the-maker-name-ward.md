# The maker-name ward: commits and pull requests no longer name a model or a harness

**Date:** 2026-11-12 · **Component:** gates (branch `eindri/no-maker-names`) · **Law:** RULES/53, appended the same day

## What was wrong

Commit subjects on `main` and several PR bodies named the tool that helped write them. The Allfather's standing word
forbids an AI signature in Ymir's commits and PRs, and he then widened it: the names of models, makers and agent
harnesses do not belong in a client's history at all. Nothing enforced either. The identity ward judged the signature
block and a few leak patterns, and nothing read the words.

## What changed

- One matcher, `bin/forge/maker-names.py`. It reads a word list with reasons (`bin/gates/maker-words.txt`), adds the
  model ids from `bin/model/catalog.sh` where a catalog exists, removes fenced blocks and `backticked spans`, and honours
  one allow file with reasons (`bin/gates/maker-allow.txt`). It names the line and the word.
- `bin/gates/guards/maker-guard.sh` is the ward every door calls: `message`, `push`, `range` and `text`.
- The commit-msg hook refuses a message; the pre-push hook refuses any new commit in the pushed range and never judges history.
- `pr_pattern_match` in `bin/forge/pr-patterns.sh` now runs the matcher, so `bin/forge/pr-open.sh` and the CI identity ward
  judge the body. Both also judge the PR title.
- The smith's `gh pr create` shim (both copies) and `bin/agents/eindri-acclaim.sh` refuse a name before a PR opens or a terminal line lands.
- The brief template gained rule 6: say "no AI attribution" and never name a tool.
- The collaboration kit moved to 1.6.0 and ships the ward, the matcher and both lists, seated in the kit's own hooks.

## Proof

`bin/gates/tests/test_maker_names.sh` runs 61 checks: every refusal, every allowed backticked path and fenced block, the
allow file, a client word list, a catalog id, the commit-msg door, the pre-push range (history ignored), `pr-open`, CI, and
the kit's copy byte for byte.

## Not done

History is not rewritten, by the Allfather's call. A word such as `pi` or `cursor` is also ordinary English; where prose
needs it, put it in backticks or add a reasoned line to the allow file.
