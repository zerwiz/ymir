#!/usr/bin/env bash
# backup-honest — a refused snapshot commit fails the backup and leaves nothing of its own staged.
gate backup-honest "a refused snapshot commit fails the backup and leaves nothing of its own staged" \
     bash "$ROOT/systems/skirnir/tests/test_backup_honest.sh"
