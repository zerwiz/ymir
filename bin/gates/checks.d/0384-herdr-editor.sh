#!/usr/bin/env bash
# herdr-editor — the input-box reader knows both harness shapes, and says unknown rather than empty.
gate herdr-editor "the input-box reader knows both harness shapes, and says unknown rather than empty" \
     bash "$ROOT/bin/seat/tests/test_herdr_editor.sh"
