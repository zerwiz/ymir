## gates · unversioned · 2026-11-14 — the repository is judged agnostic, by a ward and by a clock

### Why

Plan 287 §5, at the Allfather's word: *"it's critical that ymir's repo is 100% agnostic; our special
tooling etc belongs in ymir home."* The repository is public and ships to other operators' machines.
Two things had no ward at all:

- **What was already there.** Every existing guard judges a *diff* — the NDA gate the staged change,
  `public-guard` the tree by shape, `public-data-guard` the files a push touched. Nothing took a
  census of the whole tree against the operator's own words, so names, client companies, mail
  domains and machine names committed before the guards existed stayed, and stay, silently.
- **A list that lives where it belongs.** The words to refuse cannot be in the repository: a guard
  that names what it refuses has published it (RULES/04, RULES/18). They are read from the
  operator's home, and until now there was no home file shaped for exactly that job.

### What changed

- **`bin/gates/agnostic-audit.sh`** — one door, three postures. Without an argument it is the
  **census**: every tracked file, `--ref <ref>` reads a fetched tree instead of the working copy.
  With `check [FILE...]` it is the **ward**: only what a push ADDS, and a hit already on the base
  revision prints `inherited` and never refuses the push (plan 243 §3, part D). `--list` describes
  the classes and how many entries were read. A report for a person comes first, one machine row
  last, and the exit is non-zero on a finding.
- **Three kinds of entry, because a word scan cannot tell a machine from a figure of the lore.**
  `name:` is a person, client or company, judged anywhere; `host:` is a machine or user name, judged
  only where it is used as one (after a mailbox `@`, a URL's double slash, `/home/`, a `host=`
  setting, `ssh `); `domain:` is a mail or client domain on a domain boundary. The subsystem named
  Heimdall is the house's craft and stays; the box named Heimdall is the operator's life and is
  judged. That distinction is plan 278's lesson, and it is why this ward does not drown in prose.
- **The generic shapes are always judged**, so a machine with no list still judges something: a
  concrete private address (a CIDR range and RFC 5737 documentation space pass), and a real host
  before `ts.net` (the `<host>.tailnet.ts.net` placeholder passes).
- **The list is never printed.** A finding names the file, the line, and WHICH entry matched by its
  position in the home's file. The report can be pasted into a journal, a Telegram notice or a PR
  without publishing what it protects.
- **One shape, and it is the one that landed first.** PR #733 (the public-repo-files errand) shipped its
  own template and its own home-contract row the same night, under the house's usual name
  (`public-deny.txt.example`). This change adopts that one and drops the `.example.txt` spelling it had
  chosen, so a home is seated from one shape and `hodd/.gitignore` needs no new negation.
- **`hodd/identity/public-deny.txt.example`** ships the shape with invented entries
  (`ada-lovelace`, `client.example.org`, `host-a` — a whole invented name on purpose, because an
  entry is judged inside longer words too). **A home row** in `.agents/home-contract.yaml` seeds it
  through `bin/engine/home-seed.sh` at install, and **`.agents/migrations/0023-the-deny-list.sh`**
  seats it in a home installed before today. A file that already exists is never touched.
- **The ward joins the one list** (`bin/gates/guards.sh`): pre-push and CI both run it, scoped to the
  changed paths, never cached because it reads the home. `guards.sh` learned one small thing to hold
  it: a ward named with a shelf (`bin/gates/agnostic-audit.sh`) resolves from the repo root, and its
  verdict file is name-safe — RULES/12 puts this door in `bin/gates/`, not in `bin/gates/guards/`.
- **Two clocks, two moments, one engine — corrected at the heart's word (2026-11-14).** The first
  draft of this change folded the twice-daily job away into the private sweep, on "one capability, one
  implementation". The heart ruled otherwise and is right: the two clocks watch **different things**.
  `bin/time/nornir-job-agnostic-audit.sh` (PR #741, the heart's) fetches `origin/main` fresh and judges
  **what was published** — the moment before a leak leaves; `bin/time/nornir-job-private-scan.sh`
  (PR #732) runs after, over the **working tree**, content-wide, and triages what it finds into a queue
  and an errand. Both call the **same engine**, this repository's door, so a word is defined once and
  judged at two moments. This branch therefore ships the **door** and leaves the **job** to #741 (which
  will point it at the door when it lands); the sweep on this branch calls the door instead of spelling
  its own addresses or reading a second name list (`nda-names.txt`, which this home does not have, so
  that rule had been checking nothing, silently).
- **What the sweep gained while being joined to the door:** it runs in a Yggdrasil worktree (its
  `.git` is a file, and a `-d` test refused every one of them), a missing ripgrep skips its own half by
  name instead of stopping the whole sweep, it reads every finding rather than the first 200 (the engine
  caps its printed report for a terminal), its accept list moved from `hodd/state/` (gitignored — the
  reasons would be lost on the next clone) to `hodd/config/private-scan-allow.txt` (carried from
  `fix/agnostic-audit-job`, with the contract row it owes), and it resolves the home through
  `bin/vault/hoard-lib.sh` rather than a hardcoded fallback.
- **The halves divide, and each has one owner.** Names and places: this engine (list from the home).
  Secrets: `bin/gates/guards/secret-guard.sh` in CI, the kit's `secret-scan.sh` at pre-commit, gitleaks
  where a project carries it — a credential is a *shape*, so they need no list. The content of a record
  (a mailbox, a phone number) stays the sweep's own two rules, which no list can know. The rows ship
  commented in `.agents/config/cron.yaml.example`; the live rows are in the operator's home, gated
  `@heart`.
- **`bin/gates/tests/test_agnostic_audit.sh`** — the canary, on a throwaway repository and an
  invented list: a planted name fails the census and the report never prints it; a machine name in
  prose passes while the same name after `ssh ` fails; a documentation address passes while a
  concrete one fails; an inherited word does not refuse the push while a new line does; no list is a
  clean skip that says so; `--list` prints no word.

### The first census, written into plan 287

`bin/gates/agnostic-audit.sh --ref origin/main`, 2026-11-14: **468 findings in 279 files** — 375 of
the operator's people, clients or companies, 82 machines or users named as hosts, 7 of his own
domain, 4 concrete private addresses, 0 real tailnet hosts — read against 19 entries in the home's
list. That is the baseline phases P2 and P3 must drive to zero; nothing was fixed here, on purpose.

### What a defect in this very errand taught

The first spelling of the private-address pattern wrote the block as a two-octet prefix and then
demanded three octets after it, so an ordinary private address in the `192.168` block walked
through the ward that exists to stop it.
The canary caught it before the ward was ever seated (2026-11-14), and each range now carries all
four octets. A ward that cannot fail on its own canary is a ward nobody should trust.

And the scope was decided AFTER the first grep, so CI's posture (`check` with no files) grepped the
whole tree and then labelled every hit `inherited`: the verdict was right, the work was wrong, and on
a tree that already carried a leak the ward would have been reading the census rather than the push.
The scope is now resolved before anything is read, and `check` on this branch takes 2.1 s where it
took 20.

And joining the sweep to the engine found two more, both fixed there: its `-d "$REPO/.git"` refused
every Yggdrasil worktree (a worktree's `.git` is a file), and folding the engine's report into the queue
silently took the engine's 200-line print cap for a total — it queued "201 findings" while the tree held
470. A census that reports a screenful as a count is the false green this house keeps paying for.

### What was not changed, on purpose

- **No finding was fixed.** Plan 287 keeps P2 (code and prompts) and P3 (fix notes and docs) for
  their own errands; this one built the audit and its clock, and says what they will be judged by.
- **Nothing was installed on the heart.** RULES/41 and RULES/55: another machine's system is changed
  by its own owner. The job ships, its rows ship in the home, and the heart's Gná holder seats it.
- **It does not judge the whole tree on a push that changes nothing.** In CI on a pull request the
  ward judges the pull request's own diff; on `main` itself there is no diff, so nothing is judged
  there — that is the clock's job, and the reason the clock exists at all. A gate that turns the
  whole census red on the tree that already carries it refuses every push for history nobody wrote.
- **`config/nda-allow.yaml` stands.** The house has recorded, with reasons, that its own publishing
  names are public craft; the deny list is written not to contradict it, and a machine that shares
  such a word is a `host:` entry instead.
