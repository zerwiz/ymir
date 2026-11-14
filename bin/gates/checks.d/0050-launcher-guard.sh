# launcher-guard — the app launchers run in place on the pin and send a worktree to main's copy.
#
# Plan 275 — the update keeps every machine whole: the launchers start from the pin, the pin door
# refuses a dirty pin and rolls back an update that does not settle, Rödd's face follows its
# patches, and the hall keeps one home.
gate launcher-guard "the app launchers run in place on the pin and send a worktree to main's copy" \
     bash "$ROOT/bin/desktop/tests/test_launcher_worktree_guard.sh"
