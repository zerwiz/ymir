#!/usr/bin/env bash
# test_maker_names.sh — RULES/53: the maker ward refuses a model, a maker or an agent harness in prose,
# lets code (backticks, fences) through, and shares ONE matcher across every door.
set -u
ROOT="$(dirname "$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")")"
G="$ROOT/bin/gates/guards/maker-guard.sh"
M="$ROOT/bin/forge/maker-names.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export YMIR_MAKER_CATALOG=0
fail=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }
refused() { # label text — the ward must refuse, naming the word
  printf '%s\n' "$2" >"$T/t"
  out="$(bash "$G" text x "$T/t" 2>&1)"; rc=$?
  if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'line 1'; then ok "refuses $1"; else bad "refuses $1 (rc=$rc) $out"; fi
}
allowed() { # label text
  printf '%s\n' "$2" >"$T/t"
  if bash "$G" text x "$T/t" >/dev/null 2>&1; then ok "allows $1"; else bad "allows $1"; fi
}

# models, makers, harnesses — whole words, any case
for w in Claude ANTHROPIC opus Sonnet haiku Fable deepseek Qwen llama gemma mistral GPT OpenAI gemini grok xAI kimi GLM apodex Codex Cursor opencode Hermes aider pi copilot; do
  refused "$w" "the worker was run on $w today"
done
refused "Co-Authored-By trailer" "Co-Authored-By: Some Tool <noreply@anthropic.com>"
refused "Co-Authored-By naming an AI" "Co-authored-by: Copilot <copilot@example.org>"
refused "Generated with line" "Generated with the thing"
refused "robot emoji" "done $(printf '\xF0\x9F\xA4\x96') shipped"
allowed "a human co-author" "Co-Authored-By: Kari Nordmann <kari@example.org>"
allowed "whole-word only (pipeline, spice)" "the pipeline and the spice are fine"
allowed "a hyphenated id that merely contains a word" "the claudette-ward tool"

# code is never judged
allowed "a backticked path" 'moved `.claude/hooks/ymir-arm.sh` into place'
allowed "a backticked flag" 'run it with `--harness claude` on the worker'
allowed "an inline span of two backticks" 'the id ``deepseek-v4.1-flash`` stays'
printf 'prose line\n```\nclaude opus pi\n```\nmore prose\n' >"$T/t"
bash "$G" text x "$T/t" >/dev/null 2>&1 && ok "allows a fenced block" || bad "allows a fenced block"
printf 'prose line\n```\nclaude\n```\nthen claude in prose\n' >"$T/t"
out="$(bash "$G" text x "$T/t" 2>&1)"; printf '%s' "$out" | grep -q 'line 5' && ok "a name after the fence is line 5" || bad "line number after fence: $out"

# the allow file: a reasoned line lets a phrase through; a line with no reason does not
printf 'the Opus Dei archive\n' >"$T/t"
printf 'opus dei | a historical order, not a model\n' >"$T/allow"
YMIR_MAKER_ALLOW="$T/allow" bash "$G" text x "$T/t" >/dev/null 2>&1 && ok "a reasoned allow line is honoured" || bad "reasoned allow"
printf 'opus dei\n' >"$T/allow2"
YMIR_MAKER_ALLOW="$T/allow2" bash "$G" text x "$T/t" >/dev/null 2>&1 && bad "an allow line with no reason must not count" || ok "an allow line with no reason is ignored"

# a client tunes the list: its own words file
printf 'zorblax | model | a client-specific name\n' >"$T/words"
printf 'we used zorblax\n' >"$T/t"
YMIR_MAKER_WORDS="$T/words" bash "$G" text x "$T/t" >/dev/null 2>&1 && bad "client words" || ok "a client words file is read"
printf 'we used claude\n' >"$T/t"
YMIR_MAKER_WORDS="$T/words" bash "$G" text x "$T/t" >/dev/null 2>&1 && ok "a client words file replaces the default list" || bad "client list replaces"

# a model id from the catalog (a fake cache stands in for bin/model/catalog.sh)
printf 'madeup-model-7b-q4\n' >"$T/cache"
printf 'ran madeup-model-7b-q4 for a while\n' >"$T/t"
out="$(YMIR_MAKER_CATALOG=1 YMIR_MAKER_CATALOG_CACHE="$T/cache" python3 "$M" scan "$T/t" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'madeup-model-7b-q4' && ok "a catalog model id is refused" || bad "catalog id rc=$rc $out"
printf 'ran `madeup-model-7b-q4` for a while\n' >"$T/t"
YMIR_MAKER_CATALOG=1 YMIR_MAKER_CATALOG_CACHE="$T/cache" python3 "$M" scan "$T/t" >/dev/null 2>&1 && ok "a backticked catalog id is allowed" || bad "backticked id"

# the commit-msg door: comment lines are git's, the scissors line ends the message
printf 'ward the gates\n\n# claude is in a git comment\n' >"$T/msg"
bash "$G" message "$T/msg" >/dev/null 2>&1 && ok "a git comment line is not judged" || bad "git comment line"
printf 'ward the gates with claude help\n' >"$T/msg"
bash "$G" message "$T/msg" >/dev/null 2>&1 && bad "subject naming a harness" || ok "commit-msg refuses a subject naming a model"
printf 'ward the gates\n\nbody says Sonnet here\n' >"$T/msg"
bash "$G" message "$T/msg" >/dev/null 2>&1 && bad "body naming a model" || ok "commit-msg refuses a body naming a model"

# the pre-push door: new commits only, never history
R="$T/repo"; git init -q "$R"; git -C "$R" config user.email t@example.org; git -C "$R" config user.name t
git -C "$R" commit -q --allow-empty -m "history that says Claude long ago"
base="$(git -C "$R" rev-parse HEAD)"
git -C "$R" commit -q --allow-empty -m "a clean new commit"
head="$(git -C "$R" rev-parse HEAD)"
(GIT_DIR="$R/.git" bash "$G" push <<<"refs/heads/x $head refs/heads/x $base" >/dev/null 2>&1) && ok "pre-push ignores history, passes a clean range" || bad "pre-push clean range"
git -C "$R" commit -q --allow-empty -m "now opencode is named"
head2="$(git -C "$R" rev-parse HEAD)"
(GIT_DIR="$R/.git" bash "$G" push <<<"refs/heads/x $head2 refs/heads/x $base" >/dev/null 2>&1) && bad "pre-push dirty range" || ok "pre-push refuses a new commit naming a harness"
(GIT_DIR="$R/.git" bash "$G" range "$base" "$head2" >/dev/null 2>&1) && bad "kit range mode" || ok "the kit's range mode refuses the same commit"

# the PR door: title and body, before gh pr create
printf 'house: h\nfleet: f\nagent: r (role: ship, errand: r)\nauthority: a\nproves: p\nnever: n\n\nbody with Codex in it\n' >"$T/body"
out="$(bash "$ROOT/bin/forge/pr-open.sh" --role r --house h --fleet f --errand r --authority a --proves p --title t --body-file "$T/body" --dry-run 2>&1)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'maker' && ok "pr-open refuses a body naming a harness" || bad "pr-open body rc=$rc $out"
printf 'a clean body with `bin/forge/gather.sh --harness claude`\n' >"$T/body"
bash "$ROOT/bin/forge/pr-open.sh" --role r --house h --fleet f --errand r --authority a --proves p --title t --body-file "$T/body" --dry-run >/dev/null 2>&1 && ok "pr-open allows a backticked flag" || bad "pr-open backticked"
bash "$ROOT/bin/forge/pr-open.sh" --role r --house h --fleet f --errand r --authority a --proves p --title "ship on Sonnet" --body-file "$T/body" --dry-run >/dev/null 2>&1 && bad "pr-open title" || ok "pr-open refuses a title naming a model"

# CI: the PR title and body
for what in title body; do
  if [ "$what" = title ]; then t="Claude gets doors"; b='x'; else t="clean"; b='x\nopus tier'; fi
  printf '{"pull_request":{"title":"%s","body":"house: h\\nfleet: f\\nagent: r (role: ship, errand: r)\\nauthority: a\\nproves: p\\nnever: n\\n%s","head":{"ref":"eindri/r"}}}' "$t" "$b" >"$T/ev.json"
  GITHUB_EVENT_PATH="$T/ev.json" bash "$ROOT/bin/gates/guards/pr-identity-guard.sh" --ci >/dev/null 2>&1 && bad "CI $what" || ok "CI refuses a $what naming a model"
done
printf '{"pull_request":{"title":"clean","body":"house: h\\nfleet: f\\nagent: r (role: ship, errand: r)\\nauthority: a\\nproves: p\\nnever: n","head":{"ref":"eindri/r"}}}' >"$T/ev.json"
GITHUB_EVENT_PATH="$T/ev.json" bash "$ROOT/bin/gates/guards/pr-identity-guard.sh" --ci >/dev/null 2>&1 && ok "CI passes a clean title and body" || bad "CI clean"

# the kit's copy is the same ward, byte for byte (one matcher, two homes)
K="$ROOT/bin/collab/kit/scripts/gates"
for f in maker-guard.sh maker-names.py maker-words.txt maker-allow.txt; do
  src="$ROOT/bin/gates/guards/$f"; [ "$f" = maker-names.py ] && src="$ROOT/bin/forge/$f"; case "$f" in *.txt) src="$ROOT/bin/gates/$f";; esac
  cmp -s "$src" "$K/$f" && ok "kit carries $f unchanged" || bad "kit copy of $f differs"
done
printf 'kit ward says claude\n' >"$T/t"
bash "$K/maker-guard.sh" text x "$T/t" >/dev/null 2>&1 && bad "kit ward" || ok "the kit's own ward refuses from its own directory"

exit $fail
