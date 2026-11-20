# Galdr and Gungnir — skills, and making one

## What it is

- **Galdr** is the craft layer: the agent‑CLI standards and the **skills** — reusable
  instructions an agent finds and reads on demand. Skills are *not* preloaded; a session
  that reads forty skills acts like it read none.
- **Gungnir** is the synthesis engine: when a capability is missing, it is **forged into
  a new skill**, validated in Utgard before it is trusted.

## What you need

- Ymir installed. Skills live under `.agents/skills/` (shipped) and per‑user shelves.

## Do it

**Find a skill — do not load them all:**

```bash
bin/agents/skill-find.sh "the words you would use"   # search the descriptions
bin/agents/skill-find.sh --list                       # every skill, one line each
bin/agents/skill-find.sh --where <name>               # the exact path
bin/agents/skill-find.sh --check                      # duplicates, unfindable skills
```

Search order (first hit wins): **`.agents/skills/`** (ships) → **`.agents/skills-local/`**
(this machine) → the home's own shelf → the harness‑wide `~/.pi/agent/skills/`.

The Galdr router and its assets are the deep reference:

```bash
read .agents/skills/galdr-ymirsystem/SKILL.md          # the router + assets table
bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh
```

**Forge a skill (Gungnir):** write a skill directory with a `SKILL.md` whose front
matter carries a one‑line `description:` (unfindable without it), validate it, and
register it in the skill index. A new subsystem gets a Galdr asset — a code change not
reflected in its asset is incomplete.

## Notes and limits

- **A shipped skill beats a local one.** The project's craft is the same on every
  machine, or two developers get two answers.
- **`description:` is the index.** No one‑line description means the skill is
  unfindable — `--check` names the offenders.
- **Synthesized skills prove themselves in Utgard first** — never trusted from the forge.

## If it does not work

| What you see | What to do |
|---|---|
| A skill never loads | No `description:` in its front matter — add one; run `skill-find.sh --check`. |
| Two skills fight | Duplicated or shadowed — `skill-find.sh --check`. |
| An agent mis‑uses a skill | Read the skill's `SKILL.md`; a governed path change belongs in its Galdr asset. |
