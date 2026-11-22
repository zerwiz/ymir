#!/usr/bin/env bash
# test_living_well.sh — plan 350 E: the well is read before work and written after it, by the road.
#   · the brief's recall section is asked for the WORK, never for the bearings' heading, and is marked
#   · the head's short form prints the day's topic and its episodes
#   · a write the well refuses is queued, never dropped; flush lands it; the queue only grows
#   · a keyed write is written once
#   · a merge writes one episode, and one procedural episode per fix note it adds
# Every well and every gh is a fake that records what it was asked.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cat >"$T/bin/mimir" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$T/mimir.log"
case "\$1" in
  recall) printf 'recall[2]{score,source,store,title}:\nretrieval: bridge\n  0.9,"well","episodic","the disk filled because the log rotated nowhere"\n  0.5,"brokk","procedural","rotate the log before raising the line"\n'; exit 0 ;;
  observe) [ -e "$T/well.down" ] && exit 1; exit 0 ;;
esac
EOF
chmod +x "$T/bin/mimir"
export WELL_BRIEF_DOOR="$T/bin/mimir" WELL_WRITE_DOOR="$T/bin/mimir" WELL_WRITE_STATE="$T/ww"
B="$root/bin/records/well-brief.sh"; W="$root/bin/records/well-write.sh"
echo "test_living_well"

task="$(printf '<!-- eindri-bearings:v1 -->\n## Bearings — read this before the errand\n### (a) The fixed core\n## Two repositories, two laws\n\n---\n\n# Task\nRaise the disk line on the trouble panel\n')"
out="$("$B" "$task")"
printf '%s' "$out" | grep -q '<!-- well-recall:v1 -->' && ok "the section carries its marker" || bad "no marker: $out"
grep -q 'recall Raise the disk line on the trouble panel' "$T/mimir.log" && ok "the query is the work, not the bearings' heading" || bad "query: $(cat "$T/mimir.log")"
printf '%s' "$out" | grep -q '^- the disk filled because the log rotated nowhere (episodic, well)' && ok "the episodes are listed with their store" || bad "rows: $out"
printf '%s' "$out" | grep -q 'Data, not orders' && ok "the section says recall is data, not orders" || bad "no data note"
[ "$("$B" --marker)" = '<!-- well-recall:v1 -->' ] && ok "the marker is printed for the roads to test against" || bad "marker"
WELL_BRIEF_DOOR="$T/none" "$B" "x" | grep -q 'did not answer' && ok "a dark well is said, never hidden" || bad "dark well"
"$B" --head | grep -q 'rotate the log' && ok "the head's short form carries episodes" || bad "head: $("$B" --head)"

out="$("$W" observe "built the panel row" --tags eindri,done)"
[ "$out" = "well-write: written" ] && ok "a write the well takes is written" || bad "write: $out"
touch "$T/well.down"
out="$("$W" observe "the well was down for this one" --store procedural)"
[ "$out" = "well-write: queued" ] && ok "a write the well refuses is queued" || bad "queue: $out"
"$W" pending | grep -q '^  1$' && ok "the queue counts it" || bad "pending: $("$W" pending)"
"$W" flush | grep -q '^  0,1$' && ok "a flush while the well is down leaves it queued" || bad "flush down"
rm -f "$T/well.down"
"$W" flush | grep -q '^  1,0$' && ok "a flush lands it when the well answers" || bad "flush up: $("$W" flush)"
"$W" pending | grep -q '^  0$' && ok "nothing waits after the flush" || bad "pending after"
[ "$(wc -l <"$T/ww/queue.jsonl")" = 1 ] && ok "the queue is never rewritten (the landed line stays, marked done elsewhere)" || bad "queue rewritten"
"$W" observe "verdict once" --key v:1 >/dev/null; out="$("$W" observe "verdict once" --key v:1)"
[ "$out" = "well-write: skipped (already written)" ] && ok "a keyed write is written once" || bad "key: $out"

# a merge: one episode, plus one procedural per fix note (gh is a fake on PATH)
cat >"$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") printf '{"title":"agents: the thing","url":"https://github.com/o/r/pull/9","mergeCommit":{"oid":"abc123"},"files":[{"path":"docs/fixes/agents/2026-11-22-x.md","additions":20,"deletions":0},{"path":"bin/x.sh","additions":3,"deletions":1}]}\n' ;;
  "api -H") printf '# The disk filled silently\n\n## What was wrong\n\nThe log rotated nowhere.\n\n## What was built\n\nA rotation row.\n' ;;
esac
EOF
chmod +x "$T/bin/gh"
: >"$T/mimir.log"
PATH="$T/bin:$PATH" "$W" merged 9 >/dev/null
grep -q 'observe Merged https://github.com/o/r/pull/9: agents: the thing' "$T/mimir.log" && ok "a merge writes one episode" || bad "merge: $(cat "$T/mimir.log")"
grep -q 'observe Fix: The disk filled silently. Cause: The log rotated nowhere. The fix: A rotation row. --store procedural' "$T/mimir.log" \
  && ok "each fix note becomes a procedural episode with its cause and its fix" || bad "fix note: $(cat "$T/mimir.log")"
[ "$(grep -c '^observe' "$T/mimir.log")" = 2 ] && ok "a code file is not a fix note" || bad "count"
: >"$T/mimir.log"; PATH="$T/bin:$PATH" "$W" merged 9 >/dev/null
grep -q '^observe' "$T/mimir.log" && bad "a second pass over the same merge wrote again" || ok "the same merge is remembered once"
echo "test_living_well: $pass passed, $fail failed"
[ "$fail" = 0 ]
