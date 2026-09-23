## agents · unversioned · 2026-09-23 — the research shelf follows the craft, not the caller

### Why
A **research** artifact was filed under the **marketing** shelf. The work was
right — Huginn's Jev use-cases brief — but it landed at
`hodd/workspaces/marketing/scraped/` because `bin/research-round.sh` defaulted its
output there for every figure. The shelf then lied about what the work was.

### Fix
- **`bin/research-round.sh`** — the output shelf follows the **craft**: a marketing
  round (Bragi, Hnoss) lands on `hodd/workspaces/marketing/scraped`; every other
  figure (Huginn, Kvasir, Snotra) lands on the research shelf,
  `hodd/workspaces/personal/research`. `--out` still overrides.
- The misfiled artifact was moved to
  `hodd/workspaces/personal/research/jev-parallel-decision-use-cases-2026-09-23.md`.

### Verification
- `bash -n` clean.
- The default resolves per figure: `bragi → marketing/scraped`,
  `huginn → personal/research`.

### Files
- `bin/research-round.sh`
