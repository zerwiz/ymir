#!/usr/bin/env bash
# gather-orders-by-base — the gather merges a packet's base branch before the branch cut from it.
#
# PLAN 293 part 7 — a worker cut from another unmerged branch records that branch in its packet,
# and the gather merges the base FIRST. Gathered in the wrong order the dependent lands before its base.
gate gather-orders-by-base "the gather merges a packet's base branch before the branch cut from it" \
     bash "$ROOT/bin/gates/tests/test_gather_orders_by_base.sh"
