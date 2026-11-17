#!/usr/bin/env bash
# plan-door — the plan door knows where it belongs (plan 311): a throwaway home, three scopes from
# one door, `--host` naming which machine's shelf, an unknown project and host refused by name,
# Gimlé and Trello named as such, and one pad width per shelf.
gate plan-door   "the plan door files on the right shelf: three scopes, --host, the refusals, one pad width" \
                 bash "$ROOT/tests/test_plan_door_knows_where.sh"
