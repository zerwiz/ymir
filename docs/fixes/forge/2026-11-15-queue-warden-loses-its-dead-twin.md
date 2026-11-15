# queue-warden loses the dead twin a merge left in it

### Why

Merging the six-PR batch kept main's old `run_one` in `bin/forge/queue-warden.sh` beside the batch's `recut_one` and
`merge_one`. Nothing called it, but it carried what the warden must never do: merge main in, `git add -A`,
`--no-verify`, a skipped fixes guard and a hardcoded remote. `bin/gates/tests/test_queue_warden.sh` refused it five
times.

### What was done

`run_one` and the askpass file it used are removed. `merge_one` already asks `bin/forge/merge-verdict.sh` before any
merge, so #747's rule (no merge without a green verdict for the head sha) still holds.

### Verified

`bash bin/gates/tests/test_queue_warden.sh`: 47 pass, 0 fail.
