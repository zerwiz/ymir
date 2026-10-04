## gate · unversioned · 2026-10-04 — the bin rebuild left every caller pointing at the old door

### Why

`bin/` gained system folders and ~250 doors moved. **The doors moved; their
callers did not.** Every script that named a sibling by relative path was left
pointing at a file that no longer exists there.

The failure is silent by construction, which is the worst kind. Nothing errors at
load. A watcher execs a missing path, exits 127 before its first poll, never
writes `state/.watch.heartbeat`, and **the watch is dead while every file listing
looks correct.**

Four classes, all found by sweep rather than by reading:

| class | count | invisible to |
|---|---|---|
| literal `bin/<name>` call sites | **1,751 across 301 files** | a text search for the literal |
| `$SCRIPT_DIR/<sibling>` sources | **361 across 82 files** | any grep — the sibling assumption broke |
| other dir-variables (`$_gleipnir_lib_dir/…`) | **16** | a sweep that only knew `$SCRIPT_DIR` |
| `ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"` | **97 doors** | **Rule 12 forbids it and it was everywhere** |

### The one that matters most

**97 doors resolved the repo root by counting one `..`.** The moment a door moved a
level deeper, `..` landed on `bin/` instead of the repo root. This is verbatim the
fault `RULES/12-bin-structure.md` names:

> *"A door may never resolve the repo by counting `..`. Root is found by walking UP
> to the marker (`.pi/` + `RULES/`), because depth must not be able to blind the
> index."*

**The law was written, the restructure happened, and the law was not applied.** All
97 now walk up to the marker.

### How the sweep stayed honest

**Every destination was resolved against the filesystem, never guessed.** A
reference was repointed **only when exactly one file on disk carried that
basename**. Across all classes that produced **361 unique + 1,751 call sites +
16 dir-variables, with zero ambiguous matches**. Where no unique match existed the
reference was left alone and recorded.

### Verified

```
$ bash bin/pi/syn-watch-arm.sh          # the door Gná spawns
watcher: catch-up sweep delivered=0
watcher: started pid=1448615 recovery-generation=svc.0.4
watcher: attached - arm service up pid=1206 mode=systemd gen=3 state=…/state
exit 0

bash -n across every door touched   0 syntax errors
capabilities --check                PASS
```

**The watcher is alive.** Before this it printed
`gleipnir_lock_acquire: command not found` and exited 0 — a dead watch reporting
success.

### Still open, recorded rather than guessed

- **3 `$SCRIPT_DIR` references with no match anywhere** (`fm-extension.mjs` in two
  doors, `fm-procevent.sh`) — the file is not on disk at all.
- **9 dir-variable references unresolved** where the basename is ambiguous.
- The extension tree migration itself is on its own branch; this one is the `bin/`
  half.

### The lesson

> **A move is a relocation, never a rewrite — and every caller is repointed in the
> same commit as the move.** Rule 12 §3 says exactly this. The restructure did the
> first half and not the second, and 2,000-odd call sites went quiet at once.

The gates passed throughout, which is the part worth noticing: **capabilities,
inventory and compliance were all green while the watcher could not start.**
