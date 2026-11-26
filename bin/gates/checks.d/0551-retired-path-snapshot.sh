#!/usr/bin/env bash
# retired-path-snapshot — a dated snapshot under hodd/saves/ commits; every other new file is still judged.
gate retired-path-snapshot "a dated snapshot under hodd/saves/ commits; every other new file is still judged" \
     bash "$ROOT/bin/gates/tests/test_retired_path_guard.sh"
