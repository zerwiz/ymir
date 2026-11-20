## snotra · 2026-10-24 — Snotra becomes a system: the code leaves the time shelf

### The authority
Plan **129** — *each agent keeps its own house* (§5, §12–§14, §18). §12 corrects §5's own placement: Snotra is a
**SYSTEM**, not an app; §13 settles that an app is a collective of systems and an agent keeps a domain; §18 changes
the axis — **a domain is the primary folder, a layer is a folder inside it**, which dissolves `bin/time/`; §14-C
fixes the order of the work (shim first, callers repointed in batches, the redirect retired by a dated follow-up).

### What was wrong
- **75 files of a meeting system sat on a time shelf.** `bin/time/snotra/` was a filing convenience with no
  ownership: "who may change this?" had no answer inside the folder, and no answer in the register either
  (`hodd/identity/domains.yaml` said `folder: bin/time/snotra/`).
- **The path was load-bearing for 426 references** (287 live outside `docs/fixes/`). A move without a ledger, a
  migration and a shim is how a path becomes a dead interface — measured: 3 of the callers named the door through
  `$SCRIPT_DIR/../time/snotra/…`, a form **the ward cannot see** (it greps for the literal `bin/time/snotra`), so
  a naive repoint would have left the healer (`eir-doctor.sh`), the terminal act (`eindri-acclaim.sh`), the seat
  materialiser (`fleet-ensure.sh`) and the installer silently calling a directory that no longer holds code.

### What now stands
- **`systems/snotra/`** — the domain, end to end: `README.md` · `domain.yaml` (folder · keeper · board ·
  `memory: domain:snotra` · services · doors · `may_ask:` · `focus:` · the `policy:` block of plan 129 §20.2) ·
  `services/` · `systems/` (the record, letter and board contracts) · `memory/` · `tests/`.
- **Eight services**, each a folder of running parts, names in `domain.yaml`:
  `ear` (23 doors + the whisper `container/`) · `record` (10) · `letters` (6) · `approve` (5) · `mail-watch` (2) ·
  `cron` (16) · `tts-lease` (2) · `calendar` (5). `tests/smoke.sh` is the system's own gate.
  Every file was `git mv`'d — **nothing deleted** (Rule 11), names kept.
- **A redirect per door at the old path.** 70 one-line shims in `bin/time/snotra/`, each `exec`s the new door and
  says the move on stderr. They exist so a caller nobody has repointed still works; they are retired by this note's
  own dated follow-up, never silently.
- **The ledger and the migration.** `.agents/paths-ledger.yaml` gains `bin/time/snotra/` → `systems/snotra/`
  (2026-10-24, *ownership is the axis, plan 129*, migration `0014-systems-shelf`, superseded). The migration reads
  the per-door destination **from `domain.yaml`**, so the declaration and the healer cannot disagree; it repoints
  the home's `config/**`, `hodd/**` and `.agents/**` (cron rows first), refuses to repoint a door whose new home is
  not in the tree, and repoints a systemd unit **only when that unit names this tree** (a unit naming another
  checkout is named and skipped — otherwise a pre-merge run would take a live service down).
- **The paths are resolved, never counted** (Rule 07): every moved script's `ROOT` is a walk-up to the tree
  (`.agents` + `RULES`), with a fall back to the script's own directory so a **materialised copy in `~/.fleet`**
  still answers — proven by copying `snotra-detect.sh` beside `hoard-lib.sh` in a scratch dir and running it.
- **`bin/time/` holds only the clock and the Nornir jobs**: `sol.sh`, the `nornir-job-*.sh` set,
  `nornir-cron-start.sh`, the Sága doors, `housewatch.sh`, `brokk-wake-*.sh`, `well-vault-sync.sh`,
  `calendar-watch.sh` — plus `bin/time/snotra/` holding nothing but the shims.

### Measured
```
paths-ledger-guard check    clean — no shipped file references a superseded path (17 moves known)
files moved                 75 (git mv, none deleted)  ·  70 door shims at the old path
door refs in the shipped tree  426 total · 287 live outside docs/fixes (139 there are history, untouched) · 132 files repointed
refs the ward cannot see      23 relative `../time/snotra/` calls in 7 callers — repointed by a second pass
smoke, before the move      8 pass · 1 skip · 3 fail
smoke, after the move       8 pass · 1 skip · 3 fail      (identical — the 3 fails are pre-existing data state)
migration 0014 on a home with old spellings   heals them (6 rewrites on a scratch home, 1 on this one) · second run: 0
eir-doctor snotra surface   ok     ·     materialised ~/.fleet copy of the ear: answers
```
The three smoke failures are named, not waved: two places declare boards that do not exist (`Example`, `OptiCat`),
and one meeting folder carries a stray. Both were true **before** the move — proven by running the same gate from a
pre-move worktree at `851d8f70` and getting the identical verdict line.

### The incident in this change, and what it taught

The first draft of `0014-systems-shelf.sh` swept **all** of `hodd/` with `grep -l` + `sed`, and `grep` without `-I`
reads binary files. It rewrote 81 home files. Three consequences, all real:

1. **Two SQLite stores were corrupted**: `hodd/memory/kaia.engram` (the well's index) and
   `hodd/state/assistant/kb.db` came back `database disk image is malformed`. A byte-length-changing substitution
   inside a database is not an edit; it is damage.
   - `kaia.engram` was restored from the home's own git (`git checkout`) — `pragma integrity_check` now `ok`.
   - `kb.db` is git-ignored, so it was rebuilt through its own door: the `sqlite3 .recover` image (299 facts, 7
     people, 2 projects) was placed back as the base, then `bin/assistant/kb-export.sh` regenerated it from the 659
     approved facts. Integrity `ok`; 659 facts · 7 people · 2 projects.
2. **The append-only episode store was edited** (`hodd/memory/well/episodes.jsonl`, one 2026-10-22 episode). That is
   a Rule 06/20 violation, and it was reversed line by line: the store is back to its committed text plus the 3
   episode lines another hand had already appended. **151 episodes, none replaced.**
3. **Records that were not mine to edit** were repointed (`hodd/docs/**`, `hodd/saves/**`, `hodd/reference/**`,
   `hodd/identity/assistant/**`). All were restored by reversing exactly the substitution; the three docs that
   legitimately discuss the future `systems/snotra/` were restored from git. Verified: no remaining
   `→ bin/time/snotra` inversion anywhere in the home.

The migration now greps with `-I` (binary files are never read), names its shelves explicitly (config · .agents/skills
· the register · this tree's units), and carries the reason in its header. **The lesson, plainly: a migration heals
WIRING, never a RECORD; and a home-wide sed is a bug even when every line it changes looks like a path.**

### Owed by the incident (two commands, the operator's hand — root units)

```
sudo systemctl restart mimir.service          # :4602 still holds the corrupted image in its open fd
sudo systemctl restart well-mcp.service      # (or the unit that serves :8317)
```
After the restart the well's index has **121** of the store's **151** episodes (the git-restored image lags by 30).
The 30 exist in `hodd/memory/well/episodes.jsonl` and are not lost; re-index them from the store through the bridge
(`POST /observe` per missing episode, never by re-appending to the jsonl, which would duplicate the record). Until
then `bin/records/mimir.sh recall` answers from the store (COLD · 151) rather than the index.

### Owed — the dated follow-up that retires the shim
1. After the Allfather merges and a week of callers proves clean: **delete `bin/time/snotra/`'s shims** (a `git rm`;
   the ledger entry stays `superseded: true`, and `0014` remains the healer for any home still on the old spelling).
2. `systemctl --user daemon-reload` on every seat whose `stt-shim.service` names an old door — the tree's unit
   already execs `%h/.fleet/snotra-shim`-style materialised copies, so a seat is healed by re-ensuring the fleet.
3. The placement guard plan 129 §18 asks for (a layer directory that outgrows its name fails) is **not** shipped
   here; until it is, this rule is enforced by review. Named, not papered over.

### The law this moved under
`RULES/23` gained the append plan 129 §12/§18 requires: *a system is not an app · an app may read a system, never
contain it · a service is a process, not a place · ownership is the axis.* `RULES/26`, `RULES/28` and `RULES/30`
carry dated corrections repointing the doors they name (append-only, Rule 06).
