## skills · unversioned · 2026-09-17 — the local git round joins the loom; the stack's doors are in the registry

### Why
- **`bin/nornir-job-forgejo-git.sh` (02:45)** — reads the local forge's open
  issues each night (`$YMIR_HOME/config/forge.env` names the door; token
  optional), writes a daily digest to the hoard, carves Rune
  `forgejo / git.issues` — or `git.door-down` (exit 1) when the tunnel is
  closed, so a dead door is seen at sunrise. Unarmed without a URL, honestly.
- **The marketing stack's doors are now in the registry** —
  `marketing_doors[6]` (Mautic · Postiz · Activepieces · Forgejo · SearXNG ·
  Grafana) with reach notes, mirrored to the Galdr asset. Agents (Bragi ·
  Sindri) provision the stack for any user via
  `bin/ymir-marketing-stack.sh`, or reach the Allfather's live server stack.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md` — §3.7
(Forgejo round) and §3.8 (marketing stack provisioner); registry mirrored.

### Files
- *(carried from the frozen CHANGELOG.md)*
