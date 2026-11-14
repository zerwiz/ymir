# weave — every index names every rule, plan and feature page (plan 175).
#
# plan 175 §3 — CI keeps the LAST word on the weaver. The pre-commit hook is CONVENIENCE (it can be
# bypassed with --no-verify) and the ward runs where the tree is pushed; this row judges the merge
# the host builds, so a stale index is refused even when no hook on any machine ever fired.
gate weave      "every index names every rule, plan and feature page (plan 175)" \
               bash "$ROOT/bin/records/weave.sh" --check
