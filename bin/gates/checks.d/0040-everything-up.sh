# everything-up — seat wards: stop hook, hoard-resolved config, one-writer todos, acclaim PR guard.
#
# The rendered config resolves the home (and refuses when it cannot), worker seats are never the
# helm, there is one task-board writer, and the acclaim PR guard holds (scout exempt).
gate everything-up "seat wards: stop hook, hoard-resolved config, one-writer todos, acclaim PR guard" \
     bash "$ROOT/bin/seat/tests/test_everything_up.sh"
