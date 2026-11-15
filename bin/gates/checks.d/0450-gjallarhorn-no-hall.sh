#!/usr/bin/env bash
# PLAN 275 item 30 — the halls are local. A tunnel that dials a hall port is refused, and no
# shipped ingress template publishes one.
gate gjallarhorn-no-hall "a tunnel config may not point at a hall port, and no shipped template does" \
     bash "$ROOT/bin/forge/tests/test_gjallarhorn_no_hall.sh"
