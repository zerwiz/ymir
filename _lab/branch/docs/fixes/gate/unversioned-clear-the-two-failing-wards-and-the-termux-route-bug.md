## gate · unversioned · 2026-10-17 — clear the two failing wards and the Termux route bug

### Why
Smoke sweep on the phone found has_route misreading netlink denial as no route, and five guessed homes the defaults ward refused.

### Files
- `bin/fleet/topology.sh`
- `bin/place/place.sh`
- `bin/room/gladsheim.sh`
- `bin/room/gladsheim-ensure.sh`
- `bin/agents/eir-doctor.sh`