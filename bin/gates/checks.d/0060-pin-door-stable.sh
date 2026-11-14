# pin-door-stable — the pin door refuses a dirty pin, rolls back an unsettled update, records last-good.
gate pin-door-stable "the pin door refuses a dirty pin, rolls back an unsettled update and records last-good" \
     bash "$ROOT/bin/engine/tests/test_runtime_deploy_stable.sh"
