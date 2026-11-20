#!/usr/bin/env bash
# The ward for bin/seat/rank.sh — the hall's ranking transport.
#
# The law it guards: a card with no classification SAYS SO. The door is transport and
# jev's policy is the judge, so this test asserts three things — a dark door produces no
# scores at all (never zeros, never a guess), bad input is refused in words, and when a
# real door is up, every item comes back with the three category answers intact so the
# gate can apply jev's policy to them. When no door is up the live case says `skip`
# rather than borrowing a green it did not earn.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
ok=0; fail=0; skip=0
t() { local n=$1; shift; if "$@" >/tmp/.rt.$$ 2>&1; then ok=$((ok+1)); printf 'ok   %s\n' "$n"; else fail=$((fail+1)); printf 'FAIL %s\n' "$n"; head -4 /tmp/.rt.$$; fi; }
s() { skip=$((skip+1)); printf 'skip %s\n' "$1"; }

t "a dark door produces no scores" bash -c \
  "echo '[{\"id\":\"a\",\"text\":\"x\"}]' | JEV_RANK_DOOR=no-such-door bash '$root/bin/seat/rank.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"error\") and not d.get(\"answers\"), d'"

t "a dark door names the reason, and it is about the door" bash -c \
  "echo '[{\"id\":\"a\",\"text\":\"x\"}]' | JEV_RANK_DOOR=no-such-door bash '$root/bin/seat/rank.sh' | grep -q 'no decision door is up\|no reachable door'"

t "empty input is refused" bash -c \
  "echo '[]' | bash '$root/bin/seat/rank.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"error\"), d'"

t "input that is not JSON is refused" bash -c \
  "echo 'not json' | bash '$root/bin/seat/rank.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"error\"), d'"

t "no score is ever invented without a door" bash -c \
  "echo '[{\"id\":\"a\",\"text\":\"x\"},{\"id\":\"b\",\"text\":\"y\"}]' | JEV_RANK_DOOR=no-such-door bash '$root/bin/seat/rank.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert not (d.get(\"answers\") or {}), d'"

# Live: only when some door actually answers, so a borrowed observation is never painted
# as this seat's own green.
up="$(bash "$root/bin/model/jev-doors.sh" list --json 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: print(""); raise SystemExit
print(" ".join(x["id"] for x in d.get("doors",[]) if x.get("state")=="up"))' 2>/dev/null)"
if [ -n "$up" ]; then
  t "a live door answers all three categories" bash -c \
    "echo '[{\"id\":\"t1\",\"text\":\"a vendor claims 40 percent faster inference with no benchmark and no method\"}]' | \
     JEV_RANK_DOOR='${up%% *}' bash '$root/bin/seat/rank.sh' | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d.get(\"door\"), d
a=(d.get(\"answers\") or {}).get(\"t1\") or {}
for k in (\"hype\",\"facts\",\"signal\"):
    assert a.get(k,{}).get(\"type\")==\"score\", (k, a)
    assert \"confidence\" in a[k] and \"legend\" in a[k], a[k]'"
else
  s "no decision door answered — the live case was not asserted"
fi

printf 'rank door: %s ok / %s fail / %s skip\n' "$ok" "$fail" "$skip"
rm -f /tmp/.rt.$$
[ "$fail" = 0 ]
