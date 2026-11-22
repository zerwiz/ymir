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

## Every night: Gróa, then Eir

Every install seats a nightly pair, and every update seats it again:

- **Gróa** runs at 04:MM, a minute chosen per machine (`groa-agent.timer`).
- **Eir** runs straight after her (`eir-night.service`), whether Gróa succeeded or failed.

Eir checks every surface and mends only the ones whose risk is `safe`, then checks again. Next it renews the
installed apps. That step is skipped while the desk is in a call or a smithy run is mid-phase. Last, it hands its
verdict to the arm holder.

Neither unit ever asks for root (`YMIR_NO_SUDO=1`): a step that needs root is skipped and named. Every stage is
bounded, and a stage that runs out of time is named in the verdict. The last night's verdict is in
`state/renewal/last-night.json`.

| Platform | What is seated |
|---|---|
| Linux, and WSL with systemd | user units: the timer, Gróa's service, and Eir's service chained after it |
| macOS | one launch agent, `org.ymir.renewal`, that runs Gróa, then Eir |
| no user service manager | nothing; the seat says so (a clean skip) |

Eir's `renewal` row is red when the pair is not seated, when the last night failed, or when no night has run for
36 hours. Its mend re-seats the pair: `bin/agents/eir-doctor.sh fix renewal`.

Run one night by hand and read its journal:

```bash
systemctl --user start groa-agent.service       # Gróa, then Eir after her
systemctl --user start eir-night.service        # Eir's night alone
journalctl --user -u groa-agent.service -u eir-night.service --since today
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

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-12** — Plan 278: an update no longer stops at the check. Gróa has Eir mend every `safe` surface
  (`bin/agents/eir-doctor.sh fix --safe`), checks again, and ends on one true line: `whole`, or each owed
  surface with its exact command (exit 4). Eir's surfaces and their risk classes are in `config/surfaces.yaml`.
  The full page: [an-update-finishes-the-installs.md](an-update-finishes-the-installs.md).
- **2026-11-22** — appended: *Every night: Gróa, then Eir* (plan 350 C).
