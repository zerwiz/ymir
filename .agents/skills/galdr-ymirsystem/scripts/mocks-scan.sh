#!/usr/bin/env bash
# mocks-scan.sh <root> — the mocks gate's one implementation.
#
# WHY THIS FILE EXISTS. The mocks row in `compliance-check.sh` was a pipeline written inline: no test could
# reach it, so every exclusion it grew over a year was unproven — and each new legitimate use of one of the
# four words arrived as a red gate that a later hand judged by eye. A gate whose own shape cannot be tested is
# a gate that drifts. This is the same scan, in a file, with a probe beside it
# (`.agents/tests/mocks-scan.test.sh`) proving it BOTH refuses a stub AND excuses the vocabulary.
#
# WHAT IT LOOKS FOR: the words `mock · stub · placeholder · todo` in shipped code under <root>/bin — the four
# words that name something unfinished. It is about shipped BEHAVIOUR, never about prose.
#
# WHAT IT EXCUSES, and why each is not a stub:
#   · a comment line — a header that explains WHY a guard exists may use the word ("it was an empty
#     placeholder, but the shape invited the leak"). Documentation, not behaviour.
#   · `PUBLIC=` — the value of a public marker, not a stub.
#   · the KIND vocabulary of RULES/42 (`seeded · stub · defaulted · optional · generated`): a door that
#     switches on a kind is reading the contract's vocabulary. Matched as the LIST, so a lone `stub` is still
#     caught.
#   · the allowlist REASON vocabulary of RULES/17 (`consumer: <who>` · `todo:<section>`), demanded as the
#     PAIR — a lone `todo` is still caught.
#   · `bin/mcp/ymir-mcp.py` and `bin/seat/ymir-mcp.py` — they mirror Pi's own tool names (`todo`, `subagent`,
#     `skill`). A NAME, not a stub.
#   · the collab kit's `advantage-audit.sh` — its regex and its verdict ARE the vocabulary; the file's whole
#     job is to detect those words in a document, so naming them is the behaviour, not a stub.
#   · ONE declared FIXTURE: `bin/seat/tests/test_seat_reap.sh` stands a `herdr` on PATH
#     (a temp file the ward writes, never shipped behaviour) so the seat CLOSER can be
#     proved without closing — or refusing to close — a live workspace that belongs to
#     somebody else's errand. Declared here rather than hidden in the ward: a fixture the
#     scan knows about is a fixture, one it does not is a stub.
#   · a path ending in `todo.md` or `todo-<name>.md` — the operator's own note file
#     (`hodd/life/personal/me/todo.md`) and the lists the voice keeps beside it
#     (`todo-voice.md`). A FILENAME, not a stub; `bin/gates/guards/public-guard.sh`
#     already allows `TODO.md` for the same reason.
#
# Exit: 0 no hits · 1 hits printed · 2 usage.
set -uo pipefail
ROOT="${1-}"
if [ -z "$ROOT" ] || [ ! -d "$ROOT/bin" ]; then
  printf 'usage: mocks-scan.sh <root-with-bin/>\n' >&2
  exit 2
fi

hits="$(grep -rnE '\b(mock|stub|placeholder|todo)\b' "$ROOT/bin" 2>/dev/null \
  | grep -viE '^[^:]+:[0-9]+:[[:space:]]*#' \
  | grep -v 'PUBLIC=' \
  | grep -vE 'seeded[ |·]+(stub|defaulted)|stub[ |·]+defaulted' \
  | grep -vE 'consumer:.*todo:|todo:.*consumer:' \
  | grep -vE '^[^:]*bin/(mcp|seat)/ymir-mcp\.py:[0-9]+:' \
  | grep -viE 'todo[-a-z]*\.md' \
  | grep -vE '^[^:]*bin/collab/kit/scripts/advantage-audit\.sh:[0-9]+:' \
  | grep -vE '^[^:]*bin/seat/tests/test_seat_reap\.sh:[0-9]+:' || true)"


if [ -z "$hits" ]; then
  exit 0
fi
printf '%s\n' "$hits"
exit 1
