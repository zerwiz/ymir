## install · unversioned · 2026-10-12 — the shape law: one resolver, and the install/update obey it

### What

The Allfather's word: *"we have multiple features that depend on fleet or single machine
logics"* — and *"ymir updates and installations must have fleet and single machine logics."*
Ymir already ships the answer and had not made it law: **`bin/fleet/topology.sh`** reports
`shape` (`single` | `fleet`), `roles`, `heart`, and `link` (`standalone` | `attached` |
`detached` | `offline`) from ONE registry, and degrades cleanly to `single`/`standalone` on
a box with no registry.

This record adds the requirement to the two surfaces a user would read: the install asset
and Gróa's skill now both say that a shape‑dependent step **asks `topology.sh`** and never
re-derives the shape by hand (plan 76, the shape law). The reason is Rule 07's reason
applied to topology: five private copies of "am I a fleet?" is five chances to drift, and
the drift is silent — one feature believes it is a lone box while another believes it is a
seat.

### Verified

- `bin/fleet/topology.sh` answers live on this seat: `shape=fleet`, `heart=zerwizserver`,
  `roles=dev`, `link=attached` — the resolver works and is already the single source.
- The notes are marked **planned** where the room is concerned, and **law** where the
  resolver is concerned; nothing claims a step that does not yet run.

### Files

- `.agents/skills/galdr-ymirsystem/assets/installation.md`
- `.agents/skills/groa-update/SKILL.md`
