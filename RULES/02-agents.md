# Rule 02 — Agents (Brokk, the Eindri, and where they live)

**Status:** law. Read with Rule 01 (domains · houses · Eindri).

## 1. One home for agents

Agent profiles live **only** in **`.agents/agents/*.md`**. That directory is the
source of truth; everything else binds to it.

- Harness directories are **symlinks**, never copies:
  - OpenCode: `.opencode/agents/<name>.md` → `../../.agents/agents/<profile>.md`
  - Pi: `.pi/agents/<profile>.md` → the same canonical files
- **Never edit** `.opencode/agents` or `.pi/agents` — they are links. Edit
  `.agents/agents/<profile>.md` and re-run `bin/valknut-load.sh --all`.

## 2. The two kinds of agent

| Kind | Who | Where |
|---|---|---|
| **Primary** | **Brokk** — the bellows; sole contact with the Allfather | `.agents/agents/brokk.md` |
| **Eindri** | the workers — isolated smiths in Utgard on Yggdrasil worktrees | `.agents/agents/<name>-<craft>.md` |

Every **Eindri** is a **specialist**: a marketer, a builder, a researcher, a
planner, a reviewer, a documenter, a scout, and their kin. An Eindri is never a
domain and never a house (Rule 01).

## 3. The profile contract

Every profile carries, in frontmatter:

```
name        the agent id (short, lowercase)      e.g. sindri
norse_name  the figure the craft is named for    e.g. Sindri
descriptor  the craft in a word                  e.g. smith
domain      the field it belongs to (Rule 01)    e.g. brokkforge
role        the functional role                  e.g. developer
capabilities  the skills list
tools       the allowed tools
mode/model/permission   the harness binding (OpenCode) — from the canonical
```

- **Name for the role, never the mood.** The Norse figure must match the craft
  (Sindri smiths, Bragi sings, Mímir remembers, Förseti judges).
- **Domains:** agents knowledgeable about the **system itself** belong to
  **Ymir Labs** (`ymirlabs`).
- The file name is `<name>-<craft>.md`; the harness link is `<name>.md`.

## 4. No mock agents

- Agent ids, names, domains, models, and status must be **real** and sourced
  (from the profile, the harness config, or live signals). **Never fabricate**
  status, traceability, task counts, or uptime.
- The **demo** roster (`apps/hlidskjalf/src/data/mock.ts`) is the single, clearly
  labelled mock and appears only in demo mode; it never stands in for live data.

## 5. Changing an agent

1. Edit `.agents/agents/<name>-<craft>.md`.
2. Run `bin/valknut-load.sh --all` to rebind the harness symlinks.
3. If a governed path changed, update the owning Galdr asset in the same change
   (compliance gate `assets`).

## Permissions — bash is the hole

- A profile's `permission:` block is law for that agent over the tools.
- **A flat `bash: allow` is a total shell and overrides every `edit`/`write`
  deny.** A read-only agent with `edit: deny` but `bash: allow` can still write,
  delete, and reach the network. Never give a read-only agent a flat
  `bash: allow`; give it a **pattern map** — only the read commands it needs are
  `allow`, everything else is `ask` or `deny`.
- Network commands (`curl`, `wget`, `ssh`, arbitrary binaries) are `ask` at
  least. Code you do not fully trust belongs in **Utgard** (no host root, no
  network), not on the host behind a permissive shell.
- `mode: all` (runnable) plus a full shell is the widest door — usually not what
  you want.
- `bin/perm-guard.sh` flags any profile with a flat `bash: allow`
  (`--strict` exits 1). Run it before claiming an agent change done; see the
  runbook `docs/runbooks/agent-permissions.md`.
