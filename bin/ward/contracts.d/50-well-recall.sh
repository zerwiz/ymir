#!/usr/bin/env bash
# A recall from the well returns episodes (plan 350 E): the well is not merely running, it answers.
[ -x "$YMIR_ROOT/bin/records/mimir.sh" ] || { echo "skip: the well door is not in this tree"; exit 0; }
out="$(timeout 30 bash "$YMIR_ROOT/bin/records/mimir.sh" recall "the house" --k 1 2>/dev/null | head -1)"
case "$out" in
  recall\[[1-9]*) echo "ok: the well answered ($out)" ;;
  *) echo "red: a recall returned no episode (${out:-no answer}) — bin/records/mimir.sh recall test"; exit 1 ;;
esac
