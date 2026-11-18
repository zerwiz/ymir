# claims.sh — seat claim ledger (plan 234 §11)

Added bin/seat/claims.sh: per-seat claim files at $YMIR_HOME/state/claims/<host>-<seat>.json.
Verbs: claim, release, list [--json], who, --check. Informs, never locks; refusal only for same plan+branch.
