#!/usr/bin/env bash
# mocks-vocabulary — the mocks scan catches a half-built door and excuses only vocabulary.
#
# The mocks gate was an inline pipeline with no test, so every exclusion it grew arrived as a false
# red on legitimate code and was judged by eye. The scan is a file now, and this proves it bites
# AND stays narrow.
gate mocks-vocabulary "the mocks scan catches a half-built door and excuses only vocabulary" \
     bash "$ROOT/.agents/tests/mocks-scan.test.sh"
