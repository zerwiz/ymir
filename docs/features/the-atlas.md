# The atlas — where we have it all

**What it is.** One page at the top of your home, `hodd/ATLAS.md`, that answers *"where do we have it all?"*: every
company you run work for, its status and people, its board (Trello or Gimlé), its projects with their repositories and
where they are checked out on this machine, where its plans, documents, meetings and decisions live, what is still open,
and which plans have gone stale. Then the doors that cut across everything — your todo, the masterplan, personal plans,
runbooks, research, the daily log.

## What you need

Your home's two registries: `hodd/identity/companies.yaml` and `hodd/identity/projects.yaml`, and one folder per company
under `svartalfaheim/`. A company may declare `board: trello` or `board: gimle`.

## Do it

    bin/records/atlas.sh              # write hodd/ATLAS.md
    bin/records/atlas.sh --stdout     # print it instead
    bin/records/atlas.sh --check      # exit 1 when a project names a company folder that does not exist
    bin/records/atlas.sh --self-test  # the proofs, on a fixture home

Add `@dev 06:50 bin/records/atlas.sh` to your home's `config/cron.yaml` to rebuild it every morning.

## Limits

- It is a rendered view: never edit it — change the registries or the folders, and regenerate.
- "Stale" means a company's `plans/` folder has not changed for 7 days; it says nothing about whether the plans are right.
- "Open decisions" are documents whose header says `kind: decision` and whose status is not `live`, plus any
  `open-questions.md`.

## If it does not work

- *"YMIR_HOME is unresolved"* — set `YMIR_HOME` to your home.
- *"PyYAML is required"* — `pip install pyyaml`.
- *A company is missing* — it is not in `companies.yaml`, and no project names its folder.

## CHANGE LOG

- **2026-11-11** — first written with the atlas (plan 251).
