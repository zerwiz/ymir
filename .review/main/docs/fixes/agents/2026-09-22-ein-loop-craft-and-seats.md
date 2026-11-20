## agents · unversioned · 2026-09-22 — the loop grows the craft, the scouts, and the herdr seats

### Why
The loop's first stroke carried mission and laws but no craft — Eindri skills
were never attached (the Allfather's question), and a recon errand needed a
one-command maker. The herdr skill (read) showed the native seat roads.

### What
- `--figure`/`--skills` join the **handoff minimum (10 → 12)**: every
  `plan.md` carries the figure card + the skill paths (resolved against
  `.agents/skills/` and the pi skills, "load before acting"); a dispatch
  without a craft is refused unless `--no-skill`.
- `scout <id> "<question>"` — one command per recon errand (mission = the
  question, done = the report).
- Seats are herdr-native: scouts → `eindri-start.sh <brief> --space` (one
  errand, one space; tmux fallback); ships → `einherjar-spawn` worktrees.
  `steer` also sends live via `eindri-send.sh`; new `read` command uses
  `eindri-control.sh read`.

### Files
- `bin/eindri-dispatch.sh` (craft enforcement · scout · herdr wiring)
- `docs/fixes/agents/2026-09-22-ein-loop.md` (the base note; this is the
  follow-on stroke)

### Proof
craft refusal verified (3 predicates); a dispatched errand's plan.md carries
figure + skills; syntax + compliance green.
