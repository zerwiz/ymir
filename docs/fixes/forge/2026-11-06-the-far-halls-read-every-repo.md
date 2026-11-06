# The forge grew senses: the registry tells the truth, and intake reads every repo

**Date:** 2026-11-06 · **Plan:** 207 §P0 · §P1 · **Components:** forge · runtime (`bin/agents/project-git.sh`) · gate (the test) · agents (the asset)

## What was missing

At the Allfather's word — *"we need to have so the user can add all his repos he's working on. and we wanna see
issues and a lot more from the githubs capabilities"* — the tree was measured, not remembered:

| measured 2026-11-06 | value |
|---|---|
| rows in `hodd/identity/projects.yaml` | **78** |
| rows that could not name a remote (`git{}` absent or `owner: ?`) | **56** |
| rows with no local clone | **67** by a naive walk; `doctor` measures 11 as *far* and 14 as resolved |
| repos Glitnir could read | **1** — `reviews()` took `--repo` from this tree's own origin |
| issue readers in the whole tree | **1 line** — `mjollnir.sh:79` `gh issue view` |
| `gh` estate reachable from this seat | 100 repos on `zerwiz`, 46 with issues on, 32 private |
| open issues, that hour | 0 on `zerwiz`; 3 under `Way-Of` |

So the engine was already repository-agnostic — `mjollnir run --repo <dir>` and `yggdrasil create --repo <path>`
never cared which repo — and the **senses** were missing. This change adds two of the four, and refuses to fake the
other two.

## What this adds

**1 · `bin/agents/project-git.sh doctor [--probe] [--strict] [--json]`** — the registry's own truth. One TOON row
per project (`git` complete? clone found? remote reachable? issues on?) plus a `findings[]` row per fault, naming
the row and the reason. Offline by default; `--probe` asks GitHub once per row; `--strict` exits 1 on any `no-git`
or `unreachable`, so it can become a gate the day the remainder is healed. It writes nothing. Clone resolution is
exactly three bases — the code tree, `$HOME`, `$YMIR_HOME` — never a guess beyond them.

**2 · `bin/forge/intake.py` + `bin/forge/mjollnir.sh intake`** — the read. Every registered repo, five sources
(`repo` · `issues` · `prs` · `runs` on the default branch · `alerts`), cached under `$YMIR_HOME/state/intake/` with
a TTL. Flags: `--repo <id>` (repeatable), `--ttl` (0 = always re-read), `--limit` (repos per run; the rest are
`deferred` and named), `--cache-only` (no network at all), `--json`.

**3 · `bin/forge/mjollnir.sh run --project <id>`** — the registry resolves the tree, so a far repo is never
remembered by path. An id with no clone is **refused with the road to take**: it can be read, not fixed.

**4 · A test that proves the honesty** — `bin/gates/tests/test_mjollnir_intake.sh`, eleven proofs, no network: a
row without a `git{}` block costs **zero** `gh` calls and appears in the unread table; a second run inside the TTL
makes **zero** calls; `--ttl 0` re-reads; one failing source leaves the rest standing and names itself; `--repo`
spends no call on an unasked repo; an unknown id is refused; `doctor` names the unusable row.

## The four laws the read obeys (they are the point)

1. **A source that did not answer is named with its reason.** `0` never means "I did not look".
2. **A count that is a cap is not a count** — `--limit 100` returning 100 prints `100+`.
3. **A credential gap is one fact, not N faults.** The missing `security_events` scope printed the same
   150-character error for every one of 22 repos; it now prints one short line per repo and a single
   `needs[]` row carrying the fix (`gh auth refresh -h github.com -s security_events`).
4. **The cache saves the network or it is not a cache.** The `gh auth status` probe moved behind a lazy
   call, because a fully-cached run still spent one call on it — caught by the test, not by reading.

## How it was proved

```
$ bash bin/gates/tests/test_mjollnir_intake.sh
ok   intake exits 0 on a readable registry
ok   a readable repo carries its counts and a source failure names itself
ok   a row with no git{} block is named locally and costs no call
ok   the unread table names the registry row and its reason
ok   a second run inside the TTL makes no network call
ok   an expired TTL re-reads
ok   --repo reads exactly the named project
ok   --repo spends no call on an unasked repo
ok   an unknown project id is refused
ok   --cache-only reads no network
ok   doctor names the row that cannot name a remote

all proofs held
```

```
$ bin/agents/project-git.sh doctor | tail -8
summary[6]{key,value}:
  "rows","78"
  "git-ok","22"
  "git-missing","56"
  "cloned","14"
  "no-clone","11"
  "probe","off"

$ bin/forge/mjollnir.sh intake --limit 0 --ttl 0     # 22 readable repos, 1m21s cold
intake[22]{repo,state,issues,prs,base,alerts,age_s}:
  "NousResearch/hermes-agent","partial","100+","-","skipped","0","49"
  "Way-Of/wayofteams","partial","1","13","cancelled","0","62"
  "zerwiz/ymir","partial","0","2","success","0+?","81"
  …
needs[1]{what,fix}:
  "dependabot alerts","gh auth refresh -h github.com -s security_events  (then this line disappears)"
```

## What this does NOT do (named, so it cannot be mistaken for done)

- **No board yet.** Glitnir still reads the one repo (plan 207 §P2). The cache it will render is written.
- **No audit yet.** An issue becomes a verdict before it becomes code in §P4 — this change deliberately ships no
  hammer swing.
- **The registry remainder is 56 rows.** Healing them is a human-confirmed pass (§P0.2), because a guess about
  which remote a row means is worse than a named fault.
- **Dependabot alerts stay denied** until the operator refreshes the scope; the door says so in one line rather
  than reporting a false zero.

## Files

- `bin/agents/project-git.sh` — `doctor` (VERSION 1.4.0)
- `bin/forge/intake.py` — new: the read
- `bin/forge/mjollnir.sh` — `intake`, `run --project <id>`, lazy home resolution (VERSION 1.1.0)
- `bin/gates/tests/test_mjollnir_intake.sh` — new: eleven proofs
- `.agents/skills/galdr-ymirsystem/assets/mjollnir.md` — new asset, routed from SKILL.md and assets/README.md
- `docs/features/mjollnir-issue-to-pr.md` + `docs/features/_catalogue/entries/02-003-…` — the user's front door
- `$YMIR_HOME/…/plans/207-the-far-halls.md` — the plan this answers

## CHANGE LOG

- **2026-11-06** — written with the change (plan 207 §P0 · §P1): `doctor` on the registry door, `intake` reading
  every registered repo, `run --project <id>`, eleven proofs, and the honest-read laws. The board (§P2) and the
  audit (§P4) are owed and named above, not claimed.
