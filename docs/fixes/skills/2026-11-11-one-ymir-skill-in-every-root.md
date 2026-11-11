## skills · 2026-11-11 — one Ymir skill in every root, one unscanned store behind it (plan 248 P3b)

### What
- **`bin/agents/skill-index.sh`** gains `--root`, `--root-check`, `--adopt-box` and `--root-path`. `--root` links
  every skill of every shelf, by name, into the store `$XDG_DATA_HOME/ymir/skills` (XDG's data home; links, never
  copies; the shipped shelf wins a clash; stale links are removed). It writes the ONE root skill
  `~/.agents/skills/ymir/SKILL.md`, a quoted one-line description over a generated index (name · trigger · absolute
  path, grouped by shelf, shipped first), and links `~/.claude/skills/ymir` to it. It is deterministic, so an
  unchanged shelf writes nothing. It refuses a store or box placed inside a directory a harness scans. A fifth shelf,
  **box** (`…/ymir/box-skills`), holds a machine's own skills. The shipped shelf is read from the pinned runtime when
  `runtime.env` names one.
- **`bin/seat/harness-extensions-install.sh`** gains the row `ymir-skill`: install seats it, `--check` judges it, so
  install (`step_loaders`) and update (Gróa) carry it with no new call site.
- **`bin/time/saga-session-start.sh`** rebuilds the root skill every session.
- **`bin/agents/eir-doctor.sh`** gains the surface `rootskill` (check `--root-check`, fix `--root`).
- **`.agents/migrations/0022-one-ymir-skill.sh`** (the next number on `origin/main`): it moves box skills out of
  `~/.agents/skills` into the box, compares the copy file for file before the source goes, never overwrites, and drops
  the pi/Claude links that pointed at the old place. It then seats the root and retires the repo link.
- **`.claude/skills -> ../.agents/skills` retired** (a symlink, no content; RULES/02 as amended in #661, deletion
  logged through the no-delete ward). **`bin/seat/valknut-load.sh`** no longer binds it for Claude and removes a
  leftover of that exact shape. Codex and Cursor keep theirs. **`justfile`** now reaches the visualizer through
  `.agents/skills`.
- **`bin/agents/skill-find.sh`** reaches the box shelf, follows the shipped shelf to the runtime, falls back to
  searching **full bodies** when no name or description matches, and its `--check` **names** every skill with no
  `description:` (named, not failed: four nested `nsr-compliance/assets/**/SKILL.md` lack one today).
- **`bin/agents/seat-identity.sh`** render: one sentence, *for any craft, load the `ymir` skill and follow its index*.
  **`bin/seat/seat-surface.sh --check`** refuses a render that loses it.

### Why
His word, 2026-11-11: *"it's enough with one skill to the main harnesses … have all skills in one folder, with a
SKILL.md that is indexing all things."* RULES/51: *ONE YMIR SKILL IN EVERY ROOT*, *THE STORE IS NEVER SCANNED*.
Measured before this change, a root agent outside the repo listed none of Ymir's ~200 skills. Inside the repo, Claude
listed all 34 shipped skills through the repo link, about 15 KB per turn. A box skill (`~/.agents/skills/modeltesting` on the counsellor's seat) sat
in a directory pi walks recursively.

### Verified
- `.agents/tests/skill-index.test.sh` passes 19 of 19; 12 cases are new. They prove the box skill named, moved intact
  and its dangling pi link dropped; exactly one entry in `~/.agents/skills` and Claude's link; every index path
  resolved; the shipped shelf winning a clash; front matter that parses as YAML and stays ≤ 220 bytes; a second
  `--root` writing nothing; a scanned store refused; a body-only word found; an unfindable skill named; the render
  sentence matching the check.
- **Throwaway HOME, runtime cloned from the branch commit** (the real `~/.claude`, `~/.pi`, `~/.agents`,
  `$XDG_DATA_HOME` untouched, verified absent afterwards). After migration 0022 and `harness-extensions-install`,
  pi's own session loader (`DefaultResourceLoader`) lists `omarchy, ymir` from `~` and from an unrelated git project.
  That is one Ymir skill, and it adds 246 bytes to pi's skills prompt. Claude's root holds `omarchy, ymir`
  (front matter 107 bytes). The index holds 198 paths with 0 unresolved, and `modeltesting` was carried into the box
  byte-identical (139 files). **Update:** a new shipped skill in the runtime turns `--check` stale
  (`store: missing link proof-new-skill`), the install re-seats it (199), a second migration run moves nothing, and
  eir-doctor's `rootskill` reads `ok`.
- The first proof run caught a real fault: the unquoted description (`Ymir's craft: load this…`) is invalid YAML, and
  pi dropped the skill silently. It was fixed by quoting, and the test now parses the front matter.

### Not done
- Claude was proved structurally (its documented one-level `~/.claude/skills/<name>/SKILL.md` read), not by a live
  `claude` session in the throwaway HOME. That would need copying a credential into a scratch directory, and this
  errand declined to.
- OpenCode and Codex read `~/.agents/skills` natively (plan 248, read online). Neither binary is on this box, so
  neither was run.
- Second-machine proof (plan 248 P7) and the per-harness byte meter (P6) are owed.
- The counsellor seat's box contract (`~/CLAUDE.md`) still names `~/.agents/skills/modeltesting` and
  `~/.pi/agent/skills/modeltesting`. After migration 0022 runs there, that skill lives at
  `$XDG_DATA_HOME/ymir/box-skills/modeltesting` and is reached through the `ymir` index. The box contract is
  append-only and outside this repo, so it gets a dated line from the seat.

### CHANGE LOG

- **2026-11-11** — written with plan 248 P3b.
