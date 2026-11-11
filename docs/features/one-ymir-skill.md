# One Ymir skill in every root — the index of every skill, by path

## What it is

Ymir holds about two hundred skills across its shelves: the ones that ship with Ymir, your machine-only ones, your
own craft in the home, and this box's own. Every skill an agent harness *lists* puts its description into every
single turn, so listing all of them would cost tens of kilobytes per turn, and listing none (as the root agents did
outside the repo) left them without Ymir's craft.

So every harness's root now lists exactly **one** Ymir skill, called `ymir`. Its body is a generated index: one line
per skill, giving the name, a one-line trigger and the absolute path to its `SKILL.md`. The agent loads `ymir`, finds
the line that fits the task, and reads that one skill by path. That costs about two hundred bytes per turn, not two
hundred descriptions.

Behind it is the **store**, `~/.local/share/ymir/skills`. It holds one link per skill, gathered from every shelf, in
a directory no harness scans. When two shelves hold the same name, the shipped skill wins on purpose. A machine's own
skills (the **box** shelf) live in `~/.local/share/ymir/box-skills`.

## Where each harness finds it

- **pi, OpenCode and Codex:** `~/.agents/skills/ymir/SKILL.md`. They read that directory natively.
- **Claude Code:** `~/.claude/skills/ymir`, which links to the same directory. Claude reads its skills shelf one
  level deep.
- **The contract** in every root says it in one sentence: *for any craft, load the `ymir` skill and follow its
  index*.

## What you need

- Ymir installed. The install seats it, every update re-seats it, and every session start rebuilds it.
- Nothing else. A harness that is not installed simply never reads the file.

## Do it

```bash
bin/agents/skill-index.sh --root          # build the store and the ymir skill (idempotent; unchanged means nothing written)
bin/agents/skill-index.sh --root-check    # is it current? names a missing link, a stale index, a box skill in the way
bin/agents/skill-index.sh --root-path     # where the ymir SKILL.md is
bin/agents/skill-index.sh --adopt-box     # move this box's own skills out of ~/.agents/skills, intact
bin/agents/skill-find.sh "<words>"        # search names and descriptions, then the full bodies
bin/agents/skill-find.sh --check          # the index is fresh, and every skill with no description is named
bin/agents/eir-doctor.sh check            # the `rootskill` row says whether the roots are right
```

`--root-check` should end with `root-skill current: one `ymir` skill, N skills in the store`.

## Notes & limits

- **The index is generated, never versioned and never hand-edited.** Change a skill on its own shelf, and the next
  install, update or session start rebuilds the index.
- **The store must never sit inside a scanned directory.** pi walks `~/.agents/skills` and `~/.pi/agent/skills`
  recursively, so a store there would put every description back into every turn. `--root` refuses such a store.
- **Box skills move once.** Migration `0022` moves any real skill directory out of `~/.agents/skills` into the box
  shelf. It compares the copy file for file before it removes the source, and it never overwrites. Links to Omarchy's
  own skills (symlinks into `/usr/share`) are the operating system's, and are left where they are.
- **Inside the Ymir checkout**, Claude no longer lists the 34 shipped skills through the old repo link
  `.claude/skills`. That link is retired, and the root `ymir` skill serves instead. pi and OpenCode still see the
  repo's own `.agents/skills` as project skills when they run inside the checkout, which is the developer's view of
  Ymir.
- When a pinned runtime is set (`$YMIR_HOME/config/runtime.env`), the shipped shelf is read from the runtime, never
  from a working tree.

## If it does not work

- **The harness does not list `ymir`:** run `bin/agents/skill-index.sh --root-check`. If it says the SKILL.md is
  absent, run `--root`. If the front matter was hand-edited, `--root` rewrites it. A front matter that does not parse
  is dropped by pi without a word.
- **`box: … is a skill in a scanned shelf`:** run `bin/agents/skill-index.sh --adopt-box`, or let the next update run
  migration 0022.
- **An index line points nowhere:** the shelf moved. Run `--root` again, because it removes stale links and makes
  missing ones.
- **`skill-find --check` prints UNFINDABLE:** that skill has no `description:` in its front matter. Add one line.

Law: RULES/51 (*one Ymir skill in every root*, *the store is never scanned*). Plan 248 P3b in the home ledger.
