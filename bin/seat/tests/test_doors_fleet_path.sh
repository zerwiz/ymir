#!/usr/bin/env bash
# The ward for plan 229 — the near loop on a machine that is not this shell.
#
# WHY THIS TEST LOOKS ODD: the faults it guards against pass in an interactive shell and
# die under a systemd unit. `hlidskjalf-gate.service` sets
# Environment=PATH=%h/.bun/bin:/usr/bin:/bin, where a npm-global pi (this seat) or a
# mise-shimmed pi (the heart) is invisible — so `bin/model/catalog.sh` answered nothing,
# the window became 0, and the hall painted "—". So EVERY test here runs the doors under
# a deliberately trimmed PATH, and every door must still answer.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
ok=0; fail=0
t() { local n=$1; shift; if "$@" >/tmp/.t.$$ 2>&1; then ok=$((ok+1)); printf 'ok   %s\n' "$n"; else fail=$((fail+1)); printf 'FAIL %s\n' "$n"; head -6 /tmp/.t.$$; fi; }

t "the harness binary is probed, never assumed" bash -c '
  env -i HOME="$HOME" PATH=/usr/bin:/bin bash '"$root"'/bin/model/catalog.sh --which-pi \
    | grep -qE "\"[^\"]*/pi\",\"(PATH|probed|PI_BIN)\""'

t "the catalogue answers under the gate's PATH" bash -c '
  env -i HOME="$HOME" PATH="$HOME/.bun/bin:/usr/bin:/bin" bash '"$root"'/bin/model/catalog.sh --check >/dev/null'

t "a named model is still listed under the gate's PATH" bash -c '
  M="$(python3 -c "import json,os;p=os.path.expanduser(\"~/.pi/agent/settings.json\");d=json.load(open(p));print((d.get(\"defaultProvider\") or \"\")+\"/\"+(d.get(\"defaultModel\") or \"\"))" 2>/dev/null)"
  [ -n "$M" ] && [ "$M" != "/" ] || exit 0
  env -i HOME="$HOME" PATH="$HOME/.bun/bin:/usr/bin:/bin" bash '"$root"'/bin/model/catalog.sh --has "$M" >/dev/null'

t "core-four finds the window under the gate's PATH" bash -c '
  env -i HOME="$HOME" PATH="$HOME/.bun/bin:/usr/bin:/bin" bash '"$root"'/bin/seat/core-four.sh --json \
    | python3 -c "import json,sys;c=json.load(sys.stdin)[\"context\"];assert c[\"known\"] is True and c[\"window\"]>0, c"'

t "context reads the session under the gate's PATH" bash -c '
  env -i HOME="$HOME" PATH="$HOME/.bun/bin:/usr/bin:/bin" bash '"$root"'/bin/seat/context.sh --json \
    | python3 -c "import json,sys;d=json.load(sys.stdin);assert d[\"window\"]>0 and d[\"context_used\"]>0, d"'

t "an unknown model is unknown with a reason, never a zero" bash -c '
  H="$(mktemp -d)"; mkdir -p "$H/.pi/agent" "$H/Documents/ymirhome/config"
  printf "{\"defaultProvider\":\"somewhere\",\"defaultModel\":\"no-such-model-xyz\"}" > "$H/.pi/agent/settings.json"
  env -i HOME="$H" PATH=/usr/bin:/bin PI_BIN=/nope YMIR_HOME="$H/Documents/ymirhome" \
    bash '"$root"'/bin/seat/core-four.sh --json \
    | python3 -c "import json,sys;c=json.load(sys.stdin)[\"context\"];assert c[\"known\"] is False and c[\"window\"]==0 and c[\"reason\"].strip(), c"
  rm -rf "$H"'

size_ok() {
  python3 - "$root" <<'PY2'
import re, sys
src = open(sys.argv[1] + "/bin/seat/core-four.sh").read()
m = re.search(r"def size_of.*?(?=\nwindow, autocomp)", src, re.S)
ns = {}
exec(m.group(0), ns)
f = ns["size_of"]
assert f("65.5K")[0] == 65500, f("65.5K")
assert f("1M")[0] == 1000000 and f("1M")[1] is True, f("1M")
assert f("1.05M")[0] == 1050000, f("1.05M")
assert f("131072") == (131072, False), f("131072")
assert f("") == (0, False)
PY2
}

t "a human size is arithmetic, not string surgery" size_ok

t "pending items are complete and their ages are dates" bash -c '
  bash '"$root"'/bin/seat/pending.sh --json | python3 -c "
import json,re,sys
d=json.load(sys.stdin)
assert d[\"count\"]==len(d[\"items\"]), (d[\"count\"], len(d[\"items\"]))
for i in d[\"items\"]:
    assert {\"kind\",\"what\",\"where\",\"since\"} <= set(i), i
    assert i[\"since\"]==\"\" or re.match(r\"^20\d\d-\d\d-\d\d\$\", i[\"since\"]), i
    assert len(i[\"what\"])<=160"'

t "the wake queue keeps its whole shelf path" bash -c '
  bash '"$root"'/bin/seat/pending.sh --json | python3 -c "
import json,sys
d=json.load(sys.stdin)
w=[i[\"what\"] for i in d[\"items\"] if i[\"kind\"]==\"wake\"]
assert all(len(x)<=160 for x in w)
# a path that is present must not be cut mid-name: either it ends the cell, or it was 160-capped
for x in w:
    assert not x.endswith(\"/\"), x"'

printf 'near-loop fleet path: %s ok / %s fail\n' "$ok" "$fail"
rm -f /tmp/.t.$$
[ "$fail" = 0 ]
