#!/usr/bin/env bash
# builder-budget — 2026-11-18: the machine says HOW MANY builders it carries, and the door tells the
# truth about it. The number is the host's own row in the home's fleet registry, so the proofs are:
# it is read by hostname, an unreadable registry is UNKNOWN rather than a green zero, a machine at
# its budget refuses, and the count is made of builders in WORKTREES, not of every agent at a prompt.
gate builder-budget "the machine's builder budget is read from its own row, unknown is never zero, and a full machine refuses" \
     bash "$ROOT/bin/agents/tests/test_builder_budget.sh"
