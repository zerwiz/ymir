#!/usr/bin/env bash
# draft-weekly — the week's sweep is proved on both weeks: one that is quiet, one that is not.
#
# PLAN 305 (appended 2026-11-17). The daily brief answers "is anything too old"; the week answers
# "what did I start and not finish". A sweep that speaks on an empty week is a nag, and one that
# goes silent on a week with drafts is worse — so the proof is BOTH weeks, against a stub mailbox:
# every draft named oldest first, one trend row appended, ONE line with three buttons per draft,
# and on an empty week no message at all plus a no-op Rune.
gate draft-weekly "the weekly draft sweep: every draft, the trend, one line with buttons, silence on a clean week (plan 305)" \
     python3 "$ROOT/bin/mail/tests/test_draft_age.py"
