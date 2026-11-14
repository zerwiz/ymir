# ward — every tree ward, the whole tree.
#
# THE WHOLE TREE, EVERY WARD (plan 243 §3, part E). `--full` is the CI posture: no diff scope,
# no budget, no cache, and the wards the pre-push moved here (inventory, registers, docs-claims,
# language, dead-code) all run. This is why a local skip is still safe — nothing is judged only
# by a hook a pusher may not have installed.
#
# Its own output is kept beside the verdict file (`<verdict>.wards`), because bin/gates/main-red.sh
# reads it to name the ward and the commit that broke a red main.
ward_check() { bash "$ROOT/bin/gates/guards.sh" --full 2>&1 | tee "$VERDICT.wards"; return "${PIPESTATUS[0]}"; }
gate ward        "every tree ward, the whole tree (guards.sh --full)" ward_check
