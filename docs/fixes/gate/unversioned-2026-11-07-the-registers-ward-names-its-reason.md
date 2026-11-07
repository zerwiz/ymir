## gate · unversioned · 2026-11-07 — the registers ward names its reason, and the register counts the day door

### Why
`bin/gates/guards/registers-guard.sh` printed `registers: a register is stale …`, and the
aggregate `bin/gates/guards.sh` carries a failing ward's last line up only when it matches
`^[[:alnum:]_-]+-guard`. The prefix had no `-guard`, so the FAIL row printed an empty finding:
the ward was red and the summary said nothing, which is the "a gate that does not say why is an
obstacle" fault RULES/46 names. The message now begins `registers-guard:`, so the reason travels
into the aggregate. Measured: before, `guards.sh` printed `"registers-guard.sh","FAIL",""`;
after, the same failure prints the sentence with the remedy.

The second half is not a code change: the capability register and both inventories were stale
because `bin/day/` was a new door the register had never counted. Regenerated through
`bin/gates/registers.sh generate`, which is the door the ward itself names.

### Files
- `bin/gates/registers.sh`
- `.agents/assets/agents/capabilities.md`
- `.agents/assets/agents/capabilities/day.md`
- `bin/README.md`, `bin/*/INDEX.md`, `.agents/backend/README.md`

### CHANGE LOG

- **2026-11-07** — written with the ward message and the regenerated register.
