#!/usr/bin/env bash
# The review watcher hands one head to review once. Caught on 2026-11-22: the same head was handed again and again.
# Reads the lines that hand a review (`review <owner/repo>#<n> head <sha>`) in the wake queue and the held-reviews
# log, over the last REVIEW_REPEAT_WINDOW_H (24) hours; more than REVIEW_REPEAT_MAX (2) for one head is red.
python3 - "$YMIR_STATE" "${REVIEW_REPEAT_WINDOW_H:-24}" "${REVIEW_REPEAT_MAX:-2}" <<'PY'
import os, re, sys, time
from datetime import datetime
state, window_h, most = sys.argv[1], float(sys.argv[2]), int(sys.argv[3])
since = time.time() - window_h * 3600
pat = re.compile(r"review (\S+#\d+) head ([0-9a-f]{7,40})")
seen = {}
for name in (".wake-queue", "reviews-held.log"):
    p = os.path.join(state, name)
    if not os.path.exists(p):
        continue
    for line in open(p, errors="replace"):
        m = pat.search(line)
        if not m:
            continue
        ts = None
        first = line.split()[0] if line.split() else ""
        if first.isdigit():
            ts = int(first)
        else:
            try:
                ts = datetime.fromisoformat(first.replace("Z", "+00:00")).timestamp()
            except ValueError:
                ts = None
        if ts is not None and ts < since:
            continue
        key = f"{m.group(1)}@{m.group(2)[:12]}"
        seen[key] = seen.get(key, 0) + 1
worst = sorted(((n, k) for k, n in seen.items() if n > most), reverse=True)
if worst:
    print(f"red: {worst[0][1]} was handed to review {worst[0][0]} times in {window_h:.0f} h" + (f" (+{len(worst) - 1} more heads)" if len(worst) > 1 else "") + " — the review watcher repeats itself")
    sys.exit(1)
print(f"ok: no head handed to review more than {most} times in {window_h:.0f} h ({len(seen)} heads seen)")
PY
