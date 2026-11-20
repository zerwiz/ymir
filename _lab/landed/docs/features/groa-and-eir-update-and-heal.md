# Gróa and Eir — update, and heal

## What it is

Two keepers of a living system:

- **Gróa** — the updater shaman. She fast‑forwards Brokk and every registered
  Eindri‑home to the latest, then **mends forward** (migrations, fleet preferences).
  *Never forces, never stashes, never merges.*
- **Eir** — the healer. She **diagnoses every surface** and mends what can be mended
  safely. She composes the surfaces that already own their health; she does not
  re‑implement them.

Reach for Gróa when the code is behind; reach for Eir when something is *off*.

## What you need

- Ymir installed. Gróa may need network (to fetch); Eir needs only the machine.

## Do it

**Update — Gróa:**

```bash
bin/agents/groa-update.sh            # take the latest, then mend forward
bin/agents/groa-update.sh --check    # what would move; change nothing
```

She reports `reread-Brokk` and `galdr-reread` when the instruction surface moved — a
signal to re‑read `AGENTS.md` and reflect it in the owning asset.

**Heal — Eir:**

```bash
bin/agents/eir-doctor.sh             # diagnose every surface (TOON)
bin/agents/eir-doctor.sh fix         # mend what can be mended safely, then re-check
```

Each surface prints a row; a broken one names the remedy. Eir runs the matching repair
for the broken surfaces and re‑checks. She never arms supervision (the harness extension
owns that) and never touches a tracked tree.

They are also doors on `ymir`:

```bash
ymir groa      # the latest, and mend forward
ymir eir       # what stands, and mending
```

## Notes and limits

- **Fast‑forward only.** Gróa skips anything dirty, diverged, offline, or on a
  non‑default branch, and **reports** it — it does not take a decision for you.
- **Gróa touches code, not projects.** She moves Brokk repos and their worktrees; she
  never touches `projects/`.
- **Eir is safe by construction.** `fix` only runs repairs that cannot lose work; where
  a fix needs a human, she says so rather than guessing.
- **Neither seals a merge.** Gróa pulls and mends; delivery is still a PR (Rule 08).

## If it does not work

| What you see | What to do |
|---|---|
| Gróa reports a dirty/diverged home | Commit or resolve it by hand, then re‑run. Gróa will not force — by design. |
| `--check` shows nothing moving | You are already current; or you are on a non‑default branch (Gróa skips it). |
| Eir lists a broken surface | Run `fix`; if it stays broken, the row's remedy names the door (`bin/…-ensure.sh`). |
| A surface mends but breaks again | Something upstream owns it — `bin/agents/eir-doctor.sh` names the component; take it there. |
