# snotra · 2026-11-14 — the generic system stays; the operator's own values go home

## Files

- `systems/snotra/services/record/snotra_config.py` — **new**: the one reader of the operator's Snotra settings
- `.agents/config/snotra/snotra.conf.example` — **new**: the shape of those settings
- `.agents/config/snotra/workstreams.yaml.example` — **new**: the shape of his boards and lists
- `.agents/config/snotra/voice-subjects.yaml.example` — **new**: the shape of his spoken subjects
- `.agents/home-contract.yaml` — six rows: the Snotra and Skírnir settings, so a home receives the shapes
- `systems/snotra/services/cron/reasoning_adapter.py` — invented names in every prompt example; the board's
  workstream names read from the home; **and the module parses again**
- `systems/snotra/services/cron/snotra-trello.py` — board ids, list names and keywords read from the home
- `systems/snotra/services/ear/snotra-reason.sh` — the classifier's workstream list read from the home
- `systems/snotra/services/cron/hall-snapshot.sh` — the realm the live hall names read from the home
- `systems/snotra/services/letters/letter-design.py` — the made-by homepage: his setting, then Ymir's own site
- `systems/snotra/services/letters/snotra-letter.py` — the chair's line is the record's own words
- `systems/snotra/services/ear/snotra-voice.py` — his clients are subjects read from the home
- `systems/snotra/services/ear/snotra-autojoin.sh` · `snotra-bot.sh` — his own meeting hosts from the home
- `systems/snotra/services/cron/snotra-card-moves.py` · `snotra-dispatch.py` · `snotra-friday-synch.{py,sh}` ·
  `snotra-grooming.py` — the rules stay, the named provenance becomes the operator's
- `systems/snotra/services/letters/letter-html.py` · `record/snotra-attrib.py` ·
  `approve/meeting-record-guard.sh` — example names invented
- `systems/snotra/services/ear/snotra-{transcribe,iscall,detect,capture}.sh` — measured on *a seat*, not on a
  named machine

## Why

Plan 288 §1 drew the line: a thing belongs in the repository when any operator would need it unchanged, and in
the home when it is about **this** operator. Snotra was written with one house's values in its code — a
client's name in a prompt example, that client's workstream names in a classifier, three real board ids, a
meeting host, a chair's name in a letter paragraph, a realm name in the live hall. Plan 288 §1 and RULES/04 say
those are personal data; they published a client and a board to everyone who clones the repository, and they
gave a stranger's install three 404s and a vocabulary it has no facts for.

The same audit found a **fault that had been silent since 2026-11-03**: a correction note had been appended to
`reasoning_adapter.py` as markdown, at module level. That made the file a `SyntaxError`, so both doors that
import it (`snotra-card-moves.py`, `snotra-trello.py`) fell into their `except: pass` and the LLM reasoning pass
had not run for eleven days. The note lives inside the module docstring now, and the module compiles.

## Fix

- **One reader.** `snotra_config.py` reads `$YMIR_HOME/config/snotra/snotra.conf` (`KEY="value"`, the same shape
  every shell door already sources); `--source` says which file answered, and an absent file answers with the
  generic default the caller names.
- **The values that were in the code now live in the operator's home**: the hall's realm, the board's
  workstream names, the three boards with their lists and keywords, his spoken subjects, his letter homepage
  and his meeting hosts. Each has a shipped `.example` shape and a row in `.agents/home-contract.yaml`.
- **Every example name is invented**: Blake Ashford, Jordan Ellis. The prompts teach the same rules.
- **The chair's line** is the record's own words — `<the record's chair>, as chair, holds the register` — so no
  one person's name is written into a letter template.
- **Nothing was removed.** Every door keeps its behaviour; with the home's values seated the behaviour is
  identical to before, which the checks below measure.

## Verified

- `python3 -m py_compile` on every touched Python file; `bash -n` on every touched shell door.
- `systems/snotra/tests/smoke.sh` with the home's config: **8 pass · 3 skip · 3 fail** — identical to the
  baseline measured before the change (the three are the operator's own data: a stray file in a meeting folder
  and two Trello boards missing the lists their place profile names).
- The same smoke against a home holding only the shipped shapes: **0 pass · 1 skip · 0 fail (DECLARED EMPTY)**.
- A three-home proof (`no home`, `shapes only`, `his values`): **24 checks, 24 pass** — the reader names the file
  that answered or says the generic default did; the workstreams, boards, subjects, aliases and the hall's realm
  each answer from the right place; the repository's base canary wall binds everyone in all three.
- `letter-design.py --self-test`: ok (30 types × 3 themes) in all three homes.
- `bin/gates/checks/home-contract-check.sh`: clean — 59 rows, every template shipped, the package carrying them.
- `bin/gates/guards.sh --base HEAD`: PASS on every diff-scoped ward.
- A private-word scan of `systems/` and `tools/snotra` (the home's `public-deny.txt`, with `config/nda-allow.yaml`
  honoured): **43 findings before, 0 after**.

## CHANGE LOG

- **2026-11-14** — note written; the split done under plan 288 §1, errand `systems-split`.
