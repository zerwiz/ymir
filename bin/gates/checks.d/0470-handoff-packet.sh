#!/usr/bin/env bash
# The handoff packet is the one artefact a smith hands the reviewer and nothing ran its test. It now
# resolves a `--base` ref to a sha, so the door's own packet passes the door's own check.
gate handoff-packet "a handoff packet is sound, and the door no longer refuses the packet it just wrote" \
     bash "$ROOT/bin/gates/tests/test_handoff_packet.sh"
