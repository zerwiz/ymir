#!/usr/bin/env bash
# intake-calibrate.sh — the operator's verdicts against the machine's, and the threshold they set.
#
#   bin/notify/intake-calibrate.sh --sheet <fifty.json> --verdicts "1 s, 2 f, 3 h, ..."
#   bin/notify/intake-calibrate.sh --sheet <fifty.json> --verdicts-file <answers.txt>
#
# The sheet is the experiment record (`hodd/docs/experiments/<date>-fifty-messages.json`): one item
# per message, with the machine's verdict and confidence. The verdicts are HIS — s · f · h.
#
# It prints: agreement, a confusion table, and a threshold sweep. The chosen cut-off maximises
# agreement while never dropping a `signal` he called (a missed action costs more than a wrong
# label), and says the number it chose and why.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SHEET=""; VERDICTS=""; VFILE=""
while [ $# -gt 0 ]; do case "$1" in
  --sheet) SHEET="${2-}"; shift 2 ;;
  --verdicts) VERDICTS="${2-}"; shift 2 ;;
  --verdicts-file) VFILE="${2-}"; shift 2 ;;
  *) shift ;;
esac; done
[ -n "$SHEET" ] && [ -r "$SHEET" ] || { printf 'intake-calibrate: --sheet is required (the experiment json)\n' >&2; exit 2; }
[ -n "$VFILE" ] && VERDICTS="$(cat "$VFILE")"
[ -n "$VERDICTS" ] || { printf 'intake-calibrate: --verdicts "1 s, 2 f, …" or --verdicts-file is required\n' >&2; exit 2; }

SHEET="$SHEET" VERDICTS="$VERDICTS" python3 - <<'PY'
import json, os, re
from collections import Counter, defaultdict

sheet = json.load(open(os.environ["SHEET"]))
raw = os.environ["VERDICTS"]
pairs = dict((int(n), v.lower()[0]) for n, v in re.findall(r"(\d+)\s*[:.)-]?\s*([sfh])", raw.lower()))
if not pairs:
    print("intake-calibrate: no verdicts parsed — expected `1 s, 2 f, 3 h`"); raise SystemExit(2)

MAP = {"s": "signal", "f": "facts", "h": "hype"}
rows = []
for i, item in enumerate(sheet, 1):
    if i not in pairs:
        continue
    want = MAP[pairs[i]]
    rows.append({"n": i, "want": want, "got": item.get("machine", "?"),
                 "conf": float(item.get("conf") or 0), "text": item.get("text", "")})

total = len(rows)
agree = [r for r in rows if r["want"] == r["got"]]
print(f"intake_calibration[3]{{marked,agree,rate}}:")
print(f'  "{total}","{len(agree)}","{len(agree)/total:.0%}"')

conf = defaultdict(Counter)
for r in rows:
    conf[r["want"]][r["got"]] += 1
print("confusion[3]{you,machine_signal,machine_facts,machine_hype}:")
for want in ("signal", "facts", "hype"):
    c = conf.get(want, Counter())
    print(f'  "{want}","{c.get("signal",0)}","{c.get("facts",0)}","{c.get("hype",0)}"')

# threshold sweep: act when confidence >= t, otherwise defer (advisory).
best = None
print("sweep[8]{threshold,acted,right,missed_signal,wrong_act}:")
for t in (0.30, 0.40, 0.50, 0.55, 0.60, 0.70, 0.80):
    acted = [r for r in rows if r["conf"] >= t]
    right = [r for r in acted if r["want"] == r["got"]]
    missed_signal = [r for r in rows if r["want"] == "signal" and (r["conf"] < t or r["got"] != "signal")]
    wrong_act = [r for r in acted if r["want"] != r["got"]]
    print(f'  "{t:.2f}","{len(acted)}","{len(right)}","{len(missed_signal)}","{len(wrong_act)}"')
    if best is None or (len(missed_signal), -len(right)) < best[0]:
        best = ((len(missed_signal), -len(right)), t)

chosen = best[1]
print(f'threshold[3]{{chosen,rule,why}}:')
print(f'  "{chosen:.2f}","never drop a signal he called; among those, the most right answers","a missed action costs more than a wrong label"')
PY
