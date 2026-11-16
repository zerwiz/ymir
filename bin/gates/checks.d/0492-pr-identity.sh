#!/usr/bin/env bash
# pr-identity — the ward that judges a pull request builds its signature and still refuses a leak.
#
# WIRED, WHICH IT WAS NOT (2026-11-16). `bin/gates/tests/test_pr_identity.sh` existed and ran
# NOWHERE: no checks.d file named it, so the ward that judges every pull request was proven only
# by a hand that remembered to type the path. The test now proves both halves — the five-line
# signature is DERIVED from the pull request's own commits and author, and every real fault (an
# address, a concrete home path, a pane id, a credential, a maker's name in the title) is still
# refused — and this file is what makes CI run it.
gate pr-identity "the pull-request ward builds the signature from the PR's own commits and author, and still refuses a leak" \
     bash "$ROOT/bin/gates/tests/test_pr_identity.sh"
