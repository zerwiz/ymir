#!/usr/bin/env bash
# rodd-face-follows — Rödd's face is re-dressed when its patches change.
# While the window is in this tree its own test runs here; once it has left for its own repo (the split,
# 2026-11-19) the same test runs in that repo, and Ymir judges the installed window through apps.sh check.
if [ -f "$ROOT/apps/rodd/smoke/test_face_follows_patches.sh" ]; then
gate rodd-face-follows "Rödd's face is re-dressed when its patches change" \
     bash "$ROOT/apps/rodd/smoke/test_face_follows_patches.sh"
fi
