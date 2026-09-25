## runtime · unversioned · 2026-09-24 — a map path under another root is not a foreign home

### Why
The `hoard` check exists to catch a `.ymir-layout.yaml` carried in from **another
machine**, and it does that by asking whether each path it names exists here. Run
inside the substrate container the check failed on a map that was **entirely correct**:

```
"hoard","FAIL","layout map names paths absent here: /home/craigema/Documents/Ymir/config …"
```

The container bind-mounts the same home at its own prefix (`/home/bun/Documents/Ymir`),
so the host's paths do not exist at the container's root, and a right map was called
foreign. **A different prefix is not a different home.**

This is the same class as the session-lock pointer, and it gets the *opposite* answer.
The pointer is **machine-local** and belongs to whoever armed the session, so a host and
its container genuinely cannot agree on it. The map is **home-local**: it describes the
home, one home, wherever that home is mounted. So the map is left absolute and correct
for the machine that owns the home, and the readers learn to look again.

### What
- **`smoke_test.sh`** and **`eir-doctor.sh`** retry a map path that does not resolve as
  written: first under this root, substituting the map's own `git_repo` prefix; then, for
  a relative value, joined with this home. Only a path that fails **all** of those is
  reported as absent.
- **`eir-doctor.sh`'s remedy** no longer repoints an entry that resolves in a container's
  view of the same home. It was rewriting a correct map.
- The home's map keeps absolute paths for this machine (with `secrets`, `identity` and
  `data` under `hodd/`, which is where they belong), so it still matches the example and
  the migration that writes one.

### Verified
- The install's regression test, inside the container: **`OK=22 SKIP=14 FAIL=0`**.
- The host's own Eir still reports `hoard` broken, and correctly: on the third condition,
  the session-lock pointer naming `/home/bun/...`. That one is not this fix's to make and
  not mine to write: the pointer is session-owned, and the guard refuses a hand edit. It
  wants the decision named in the note above.

### Files
- `.agents/skills/lifecycle/smoke_test.sh`
- `bin/eir-doctor.sh`
