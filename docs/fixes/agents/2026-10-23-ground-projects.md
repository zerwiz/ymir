## agents · 2026-10-23 — the projects overview, fed to Skírnir from the registry

### Files
- `bin/assistant/ground.py` (`projects(<house|id>)` — read-only)
- `hodd/identity/assistant/approved/projects-overview.md` (generated, 23 projects)

### Why
The Allfather: *"feed Skírnir with overview data off all my projects from Whynot Productions and Way of."*
The registry held them; the assistant could name none.

### What it does
Reads `hodd/identity/projects.yaml` (the master registry), resolves each project's plan ledger by **id, repo name or
path** (`ymir-platform` lives under `projects/ymir` — the id is not always the folder), counts the numbered plans in
that ledger's index, and generates one page: house · path · posture · plan ledger.

Measured: **23 projects** across Whynot Productions, Way of and the house's own; **2 with a ledger** (ymir-platform,
67 plans, latest 121; command); the rest say **no ledger** — an absent file is not an empty one (Rule 37).

**What he may say:** a project's house, path, posture and plan count. **What he may not:** its *decisions* — those
come from the ledger and the records reader, never from memory.
