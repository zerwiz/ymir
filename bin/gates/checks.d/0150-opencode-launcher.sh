# opencode-launcher — every door seats OpenCode with the launcher's one shape; the version guard bites.
#
# PLAN 262 — an OpenCode worker actually starts. The interactive TUI refuses --model (OpenCode v2),
# four doors each built their own shape and three drifted. One launcher, four callers, and this is
# the parity test plus the version guard that keeps it from drifting again.
gate opencode-launcher "every door seats OpenCode with the launcher's one shape; the version guard bites" \
     bash "$ROOT/bin/gates/tests/test_opencode_launcher.sh"
