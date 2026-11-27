#!/usr/bin/env bash
# bin/skuld/role.sh -> bin/fleet/role.sh — a forwarding stub, plan 374 (D3, 2026-11-25).
# allow-superseded-path: this header RECORDS the move, it does not make one
#
# Which machine plays which role is a fleet fact, not Skuld's: she keeps what shall be (tickets, plans owed, the
# to-do, each branch's outcome). The resolver moved to bin/fleet/ with its history (`git log --follow`), and
# `.agents/paths-ledger.yaml` records it. This stub keeps an old cron row, a home's script or a note working for one
# release cycle. It execs, so the exit code, stdout and stderr are the door's own.
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$_d/../fleet/role.sh" "$@"
