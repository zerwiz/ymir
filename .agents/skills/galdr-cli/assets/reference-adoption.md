# Reference Adoption — data, skills, state, docs

How the inherited upstream material under `assets/` is reused by the Brokk
runtime. Load this when touching `assets/data/`, `assets/reference/*`, or the
runtime `state/` conventions. Source material is provenance; only the adopted,
Norse-named runtime is loaded.

## Data → the well (Mimirsbrunn)

`assets/data/**/*.md` is real planning/knowledge material. `bin/mimir-ingest.sh`
chunks it by heading into episodes (content hash, source, tags, timestamp) and
appends them to the local well store; it POSTs each to the engram bridge when
reachable. Idempotent by hash.

```
data_pipeline[2]{stage,path}:
  "source","assets/data/**/*.md (13 files, ~370 sections)"
  "ingest","`bin/mimir-ingest.sh` → `.agents/memory/well/episodes.jsonl` + bridge `/observe`"
```

```
runes[1]{command,purpose}:
  "bin/mimir-ingest.sh","drink the repo's data into the well (idempotent)"
```

## State conventions (Brokk)

Derived from the upstream `assets/reference/state/` samples, rewritten to the
Norse runtime. Private, gitignored under `state/`.

```
state[9]{path,holds,owner}:
  ".lock","session pid (bound to the live harness via BROKK_SESSION_PID)","Gleipnir"
  ".session-start-complete","the Sága digest has run this lock","Sága"
  ".supervision-armed","supervision was armed at least once","Sýn"
  ".watch.heartbeat","watcher liveness epoch","Sýn"
  ".wake-queue","durable wake records (ack to drop)","Sága"
  "*.signal","an actionable event for the watcher cycle","Sýn/Gná"
  "*.check","a scheduled check demand","Sýn"
  "*.meta","per-task metadata (backend, worktree, harness, mode)","Einherjar/Vör"
  "*.status","appended wake-event lines (not current-state truth)","Eindri/Vör"
```

Rule: a `state/*.status` line is a **wake event**, never current-state truth;
use `bin/vor-crew-state.sh` to reconcile reality.

## Reference skills → Norse (adopted)

The upstream internal skill library under `assets/reference/skills/` is
provenance. Each adopted skill took the Norse figure whose role matches its work
and now lives at `.agents/skills/<name>/SKILL.md`.

```
skill_map[20]{upstream,norse,status}:
  "harness-adapters","hamr","adopted"
  "afk","hvild-afk","adopted"
  "bearings","saga","adopted"
  "ahoy","saga","adopted"
  "stow","muninn-stow","adopted"
  "project-management","jord-projects","adopted"
  "decision-hold-lifecycle","urdh","adopted"
  "allfather-hold-lifecycle","urdh","adopted"
  "ask-user-authority","frigg-consent","adopted"
  "bootstrap-diagnostics","vor-diagnostics","adopted"
  "diagnostic-reasoning","vor-diagnostics","folded"
  "process-event-sources","nornir","adopted"
  "quota-array-dispatch","nornir","adopted"
  "fmx-respond","gjallarhorn-relay","adopted"
  "secondmate-provisioning","eindri-homes","adopted"
  "stuck-crewmate-recovery","syn-recovery","adopted"
  "updatefirstmate","ymir","adopted"
  "firstmate-coding-guidelines","(Galdr)","folded"
  "firstmate-orca","(reference)","reference only"
  "firstmate-codexapp","(reference)","reference only"
```

Sixteen skills adopted under `.agents/skills/`; see the registry in
`.agents/skills/README.md`.

## Reference docs → adoption (W0109)

```
doc_map[8]{upstream,adopt_as}:
  "supervision-protocols/*","`.agents/skills/galdr/assets/harness-integration/` (per-harness tier)"
  "turnend-guard.md","`bin/syn-turnend-guard.sh` + `.pi/extensions/syn-turnend-guard.ts`"
  "trace-context.md","W3C trace propagation (W0094)"
  "subagent-guard.md","Eindri pretool seatbelts (syn-*-pretool-check.sh)"
  "architecture.md","`.agents/skills/galdr/assets/brokk-distro-runtime.md`"
  "configuration.md","`.agents/config/` keys (W0104)"
  "tmux-backend.md / herdr-backend.md","`bin/` runtime backends (Valhalla)"
  "calm.md","`.pi/extensions/ro.ts` (Ró)"
```

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr/SKILL.md`.
- Move a `skill_map` row's `status` to a real `.agents/skills/<name>/SKILL.md`
  when converted (`adopted`), or `folded` when its content lands elsewhere; keep
  `assets/reference/` provenance-only.
