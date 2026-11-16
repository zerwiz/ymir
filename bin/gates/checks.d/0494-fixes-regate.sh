#!/usr/bin/env bash
# fixes-regate — the record gate judges CONTENT, so an empty re-gate owes no note.
#
# 2026-11-16. A push whose only new commits change no file — `git commit --allow-empty` to
# re-trigger the gate, or a branch re-pointed at a tree the gate has already seen — was refused
# for carrying no fix note, and a green pull request was pushed four times to satisfy a gate
# about content it did not have. The test plants a real git range for each case and proves the
# gate in both directions: an empty range passes, a range that changes a file with no note is
# still refused, and the note answers the change when it is there.
gate fixes-regate "the record gate accepts an empty re-gate and still refuses a real change with no note" \
     bash "$ROOT/bin/gates/tests/test_fixes_regate.sh"
