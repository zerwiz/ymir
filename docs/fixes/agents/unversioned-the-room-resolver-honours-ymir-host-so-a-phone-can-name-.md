## agents · unversioned · 2026-10-17 — the room resolver honours YMIR_HOST, so a phone can name itself

### Why
The room name is looked up by hostname, but the phone's hostname is 'localhost', so Dvalin could never resolve its own name. It now reads ${YMIR_HOST:-$(hostname -s)} like topology.sh and role.sh already do.

### Files
- `bin/room/gladsheim.sh`
- `bin/room/gladsheim-ensure.sh`