#!/usr/bin/env bash
# test_ratatoskr_queue.sh — ONE queue: inbox → claimed → done, and the claim is a rename.
#
# Why this test exists: the house had four mailboxes in four formats, so a message that
# landed in the wrong one reached nobody. The queue below is one format, and the two
# things a relay depends on are proved here — that exactly one receiver can claim a task
# (the rename is atomic), and that a task is not "done" until a reply is in it.
#
# Everything runs in a temporary queue directory; the real home's state is never touched.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
door="$here/../ratatoskr.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_ratatoskr_queue"
[ -x "$door" ] || { bad "the door is missing: $door"; exit 1; }

export HOME="$tmp/home"; mkdir -p "$HOME"
export RATATOSKR_QUEUE="$tmp/queue"
export YMIR_MACHINE="host-a"
q() { "$door" "$@" 2>&1; }

# 1 · a task is written to inbox/, and it carries who, to when, and what
id="$(q send herdr:w1:p2 "answer with the nonce")"
case "$id" in
  *-*) ok "send prints a task id" ;;
  *) bad "send printed [$id]" ;;
esac
[ -f "$RATATOSKR_QUEUE/inbox/$id.md" ] && ok "the task lands in inbox/" || bad "no file in inbox/"
grep -q '^from: host-a' "$RATATOSKR_QUEUE/inbox/$id.md" && ok "the sender is stamped on the task" || bad "no from:"
grep -q '^to: herdr:w1:p2' "$RATATOSKR_QUEUE/inbox/$id.md" && ok "the target is stamped on the task" || bad "no to:"

# 2 · the queue lists what is waiting, and only what is waiting for you
out="$(q inbox)"
printf '%s\n' "$out" | grep -q "$id" && ok "inbox lists the task" || bad "inbox: $out"
out="$(q inbox --for w1:p2)"
printf '%s\n' "$out" | grep -q "$id" && ok "--for matches the target" || bad "--for missed: $out"
out="$(q inbox --for somebody-else)"
printf '%s\n' "$out" | grep -q "$id" && bad "--for matched a stranger" || ok "--for does not match a stranger"

# 3 · THE CLAIM IS A RENAME: the file moves, and the task now says who took it
out="$(q claim "$id" --by w1:p2)"
[ -f "$RATATOSKR_QUEUE/claimed/$id.md" ] && [ ! -f "$RATATOSKR_QUEUE/inbox/$id.md" ] \
  && ok "claim moves the file from inbox to claimed" || bad "claim left the file: $out"
grep -q '^claimed_by: w1:p2' "$RATATOSKR_QUEUE/claimed/$id.md" && ok "the claimer is stamped" || bad "no claimed_by"

# 4 · exactly one receiver wins — a second claim is refused, not silently doubled
out="$(q claim "$id" --by w1:p3)"; rc=$?
[ "$rc" = 1 ] && ok "a second claim exits 1" || bad "a second claim exited $rc"
printf '%s\n' "$out" | grep -q 'already on claimed' && ok "a second claim says which shelf holds it" || bad "second claim: $out"
grep -q '^claimed_by: w1:p2' "$RATATOSKR_QUEUE/claimed/$id.md" && ok "the first claimer still owns it" || bad "the claim was stolen"

# 5 · a task is not done until it is answered, and the answer is the record
q reply "$id" "the nonce is 4417" >/dev/null
[ -f "$RATATOSKR_QUEUE/done/$id.md" ] && [ ! -f "$RATATOSKR_QUEUE/claimed/$id.md" ] \
  && ok "reply moves the file to done" || bad "reply did not move the file"
grep -q '^the nonce is 4417' "$RATATOSKR_QUEUE/done/$id.md" && ok "the reply is in the file" || bad "the reply is missing"
grep -q '^answered_at: ' "$RATATOSKR_QUEUE/done/$id.md" && ok "the answer is stamped with its time" || bad "no answered_at"
grep -q '^answer with the nonce' "$RATATOSKR_QUEUE/done/$id.md" && ok "the original task is kept beside its answer" || bad "the task was lost"

# 6 · the shelves count, and the whole exchange is one file the whole way through
out="$(q count)"
[ "$out" = "inbox=0 claimed=0 done=1" ] && ok "count names every shelf" || bad "count said [$out]"

# 7 · a reply to a task nobody wrote is a refusal that names it
out="$(q reply 0000-nope "hello")"; rc=$?
[ "$rc" = 1 ] && ok "a reply to an unknown task exits 1" || bad "unknown reply exited $rc"

# 8 · an empty task and an empty reply are refused — neither is a message
q send w1:p2 "" >/dev/null; [ $? = 2 ] && ok "an empty task exits 2" || bad "an empty task was accepted"
id2="$(q send w1:p2 "second task")"
q reply "$id2" "" >/dev/null; [ $? = 2 ] && ok "an empty reply exits 2" || bad "an empty reply was accepted"

# 9 · show prints the file, and a prefix is enough to name a task
out="$(q show "${id2%%-*}")"
printf '%s\n' "$out" | grep -q 'second task' && ok "a task id can be quoted by its prefix" || bad "prefix: $out"

# 10 · an id is unique per send, so two tasks never collide
id3="$(q send w1:p2 "third")"; id4="$(q send w1:p2 "fourth")"
[ "$id3" != "$id4" ] && ok "two sends get two ids" || bad "two sends shared one id"

# 11 · --json is the same rows for a caller that must not parse a table
q inbox --json 2>/dev/null | python3 -c '
import json,sys
rows=json.load(sys.stdin)
assert isinstance(rows,list) and len(rows)==4, rows
pick=[r for r in rows if r["body"]=="second task"][0]
assert pick["shelf"]=="inbox" and pick["to"]=="w1:p2", pick
done=[r for r in rows if r["shelf"]=="done"][0]
assert done["reply"]=="the nonce is 4417", done
' && ok "--json carries shelf, target and body" || bad "--json is not the documented shape"

printf '\ntest_ratatoskr_queue: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
