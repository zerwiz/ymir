# The seat's role file was composed from the seat's name — and about half the fleet pointed at nothing

**Date:** 2026-11-08 · **Component:** agents

## What was wrong

The Allfather, answering a report on why the agent switcher only offered three seats: *"håve are heimdal only.
and sindri are nidavelli only"* — a seat's **name** and the **card it reads** are two different facts, and the
code treated them as one.

Four faults, all in the same formatter (`role_file()` in `bin/agents/seat-identity.sh`):

1. **The path was invented from the name.** `role_file()` returned `<name>.md`, with four hand-written
   exceptions. The renderer then printed `.agents/agents/Hávi.md` — a file that did not exist — so the seat
   file named a card nothing followed. The 2026-11-07 fix answered this by *shipping* a link at that invented
   path. That is the shape of the bug, not its cure: a machine's seat name was written into the public tree
   so a dead pointer could resolve.
2. **The roster's own `role_file:` was ignored.** `seats.yaml` records the card explicitly
   (`nidavellir: role_file: .agents/agents/brokk.md`) and the formatter never read it. The record was right;
   the code did not consult it.
3. **The documented call order silently answered the wrong question.** The header documents
   `seat-identity.sh <host> --file`; the parser only accepted `--file <host>`. With the flag second, the door
   returned the seat's *name* and said nothing — a wrong answer that looks like a right one.
4. **The hand-written exception map was incomplete.** `whynot` (kvasir) and `zerwizserver` (forseti) pointed
   at `kvasir.md` and `forseti.md`, neither of which exists; their cards are `kvasir-scout.md` and
   `forseti-reviewer.md`. Two seats were reading nothing.

A fifth fault belonged to the same class and was found while sweeping: `.agents/agents/skirnir-assistant.md`
carried **no frontmatter**, so `bin/seat/valknut-load.sh` bound no link for it (it needs `name:`), and
OpenCode never loaded the figure at all — 24 profiles, 23 agents.

## What was done

- **The card is recorded, never composed.** `role_file()` now reads `role_file:` from the roster first; failing
  that it takes an exact `<name>.md`; failing that the prefix match the craft encodes (`kvasir` →
  `kvasir-scout.md`). The name is only a last resort, and a card that cannot be read is now **said out loud**
  on stderr instead of being rendered as if it were read.
- **`.agents/agents/Hávi.md` is retired.** It was a link to `brokk.md`, created to satisfy the invented path.
  Nothing needs it now: the seat resolves to the card the roster records. A name that belongs to one machine
  does not ship in a public tree.
- **Both documented argument orders work** (`--file nidavellir` and `nidavellir --file`).
- **`heimdall` declares its card** (`role_file: .agents/agents/brokk.md`) — the counsellor seat answers as its
  own name and reads the counsellor's text, which is the whole point.
- **Skírnir gets his frontmatter** — `name`, `mode: subagent`, a description, and a pattern-map permission
  block (no flat `bash: allow`), so he binds and loads like every other figure.

## How it was verified

```
bin/agents/seat-identity.sh --file nidavellir   → .agents/agents/brokk.md        (exists)
bin/agents/seat-identity.sh --file whynot       → .agents/agents/kvasir-scout.md (exists)
bin/agents/seat-identity.sh --file zerwizserver → .agents/agents/forseti-reviewer.md (exists)
bin/agents/seat-identity.sh --file heimdall     → .agents/agents/brokk.md        (exists)
bin/seat/valknut-load.sh --all                  → opencode/pi/claude/codex/cursor all bound (24)
opencode debug agents                           → 36 agents; every one of the 24 figures present
```

Before: 23 of 24 figures loaded, `Hávi.md` shipped a machine's name, two seats pointed at nonexistent cards.
After: 24 of 24, and no composed path in the tree.

## Still held (the Allfather's to seal)

The roster still reads `nidavellir: primary: Hávi` and `heimdall: primary: Hœnir`, which contradicts his word
this day that **Hávi is heimdall's** and **Sindri is nidavellir's**. Names are sealed by him alone (Rule 44),
so this fix leaves them untouched and asks; the card resolution above makes the naming harmless either way.

## CHANGE LOG

- **2026-11-08** — Written with the formatter fix, at the Allfather's word (*"fix the formatter"*).

## Read the published formats rather than assume them (same day)

His word: *"read online so you know the formatters work for www.pi.dev and opencode."* Read, then measured.

**OpenCode** (`opencode.ai/docs/agents`, `/docs/migrate-v1`): `.opencode/agents/<name>.md` is the preferred V2 path, and
the id comes from the **link** filename — so `bragi.md → bragi-marketer.md` still loads as `bragi`. An omitted `mode`
on a custom agent **defaults to `primary`**, which is exactly why two figures were seated by accident (`galdr`, and
before it every card that lacked one). V1 frontmatter is deprecated but translated automatically, and `opencode debug
agents` proves the translation: `permission.bash."ls *": allow` arrives as `{action: shell, resource: "ls *", effect:
allow}`. A file that uses any V2 key (`permissions`, `request`, `system`, `disabled`) is read as V2 and its V1 `name`,
`tools` and `permission` are **ignored** — so a card is converted whole or not at all, and none of ours is converted yet.

**Pi** (`pi.dev/docs/latest/configuration`, `/cli`, `/skills`): Pi core has **no agent loader** — `agents/` is not in its
configuration tables — so `.pi/agents/` is a vestigial shelf; the figures reach Pi through `.pi/extensions/ymir-subagents.ts`,
which reads the canonical tree itself. `--append-system-prompt <text|path>` accepts a path, so `herdr-run.sh` passing the
card is right. Pi implements the Agent Skills spec: a malformed `SKILL.md` or one without a `description` is **not loaded**.

**Measured on this tree:** 36 agents in OpenCode, every one of the 24 figures present, each with a readable
`name` and `description`; 44 SKILL.md discovered, all load but the four vendored `nsr-compliance/assets/` copies that
deliberately carry no frontmatter so they are not phantom skills.

**What that changed.** `galdr.md` gained the `mode: all` it never declared (an omitted mode is a *primary*, not a
neutral) and the `permission:` block it never had, so its shell is a pattern map (`"*": ask`) like every other builder.
`skirnir-assistant.md` gained its whole frontmatter. Nothing else needed converting: the cards are V1, which OpenCode
still translates, and the Pi line scanner reads every one of them.

**The rule that comes out of it:** one card, two readers, and the card is written for the weaker reader — OpenCode parses
YAML, Pi scans lines, so anywhere the two disagree the line scan wins.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the fleet's always-on heart · a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
