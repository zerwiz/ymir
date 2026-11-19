## apps · 2026-11-19 — Hvergelmir leaves for its own repo, with its history: the road is proven

### Why
The split's first app (plan 03): the least-tied app in the tree (380 files, 6 commits, no unit, no launcher, no climb out
of its folder), so it proves every step of the road while it can break nothing the Allfather uses.

### What moved
- `apps/hvergelmir/` (380 files) → `zerwiz/hvergelmir`, cut with `git filter-repo --subdirectory-filter apps/hvergelmir`:
  12 commits there, every one of the 6 that touched it here among them, authors and dates kept.
- In that repo, the app contract: `app.yaml` (kind `service`: an API on :4850 and a hub on :4851), `install.sh` with
  `--check`, `start.sh`, `stop.sh`, `uninstall.sh`, CI. A first install writes its config **outside** the release
  (`~/.config/hvergelmir/.env`) and fills the two bearer tokens upstream's `just api tokens` made; none is printed.

### What changed here
- `config/app-repos.yaml`: `contract: 1` and `moved: zerwiz/hvergelmir@2f7ce719f511`.
- `bin/no-delete-guard.sh`: a path under an app's old folder is a move when its registry row says `moved:`
  (RULES/11, appended); every other deletion is still refused (proved: `README.md` staged for deletion → rc 1).
- Its three exemptions left with it: `app-folder-guard.sh` (the nested `apps/`), `dead-code.allow` (4 rows),
  `language.allow` (the CJK fixture). `apps/README.md` gains an appended "left for" table.
- This note, and Hvergelmir's earlier note (`2026-11-06-hvergelmir-the-news-app-enters-the-tree.md`), stay here (RULES/06).

### Proof
- `bin/apps/split-ledger.py verify hvergelmir`: files 380/380 identical (git blob ids), history 6/6, records 1/1 —
  **nothing lost**.
- `bin/apps/apps.sh install hvergelmir` from the cut repo into a fenced apps home: built, `--check` green, `current`
  set; `update` across a new commit flipped and kept `previous`; `rollback` and forward again.
- `start.sh` from its home got past the tokens and stopped, rightly, at `No Jev credentials`: it needs the operator's
  model key (`OPENROUTER_API_KEY` in `~/.config/hvergelmir/.env`). That key is his to place, never copied by a worker.

### Owed
- Pushing `zerwiz/hvergelmir` (held for the one PR, at the Allfather's word).
- The move record in the home (`hodd/reference/moves/hvergelmir.md`), once the home takes a pull.
- The acceptance on a second machine.
