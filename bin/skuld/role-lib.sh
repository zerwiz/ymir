#!/usr/bin/env bash
# bin/skuld/role-lib.sh -> bin/fleet/role-lib.sh — a forwarding stub, plan 374 (D3, 2026-11-25).
# allow-superseded-path: this header RECORDS the move, it does not make one
#
# Sourced, not run: it loads the real library from its new home, so an old `. bin/skuld/role-lib.sh` keeps working
# for one release cycle. `.agents/paths-ledger.yaml` records the move.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../fleet/role-lib.sh"
