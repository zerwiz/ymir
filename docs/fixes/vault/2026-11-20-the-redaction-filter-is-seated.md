# vault · unversioned · 2026-11-20 — the redaction filter is seated, not remembered

The mail spine travels with the home now (plan 116 §18), and a credential is kept out of git by a
**clean filter**: `.gitattributes` marks `hodd/memory/mail/messages.jsonl` `filter=gna-redact`, and
the filter is `hodd/bin/mail-redact.py`. **Git config does not travel with a clone.** The filter was
seated by hand on one machine; every other seat had the attribute and no filter, and git would have
committed the letters **raw** — passwords and all — the first time anyone staged the spine there.

## What changed

- **`bin/vault/home-sync.sh setup` seats it.** The same door that already seats `merge.ours.driver`
  now seats `filter.gna-redact.clean "python3 hodd/bin/mail-redact.py"`, `.smudge cat` and
  `.required true`, and only when that script exists in the home. `.required` is the half that
  matters: without it git commits the file unfiltered when the script fails.
- **`home-sync.sh ship` refuses an unredactable path.** Before staging, every named path is asked of
  git what filter it carries (`check-attr`, so the list is never restated in code); a filtered path
  whose filter is unconfigured — or not `required` — stops the ship with the fault and the mend.
  `--dry-run` prints the same finding as a warning, because it stages nothing.
- **`home-sync.sh filter-check <path>…`** answers the question directly: does this seat redact this
  path?
- **`bin/vault/home-sync-clock.sh` seats it too.** The clock is the one thing that touches the home
  on every seat, whether or not a hand ever runs a command there, so a fresh clone is mended at the
  first hourly run instead of waiting for someone to remember.
- **`bin/mail/README.md` corrected.** It said *"the message spine is git-ignored … raw mail does
  not travel"*. That is false twice over: the spine is tracked, and it travels — redacted on commit.
  A reader who believed that line would have shipped a letter with no filter and nothing to warn
  them.

## Proof

```text
$ bash bin/vault/tests/test_home_redaction_filter.sh
setup seats the filter from the home own script
  ok   filter.gna-redact.clean = python3 hodd/bin/mail-redact.py
  ok   filter.gna-redact.smudge = cat
  ok   filter.gna-redact.required = true
a seated filter redacts the COMMITTED blob, not the working copy
  ok   the committed blob carries [redacted]
  ok   the password is not in git
  ok   the working copy keeps the letter whole
an unseated filter REFUSES the spine
  ok   ship exits 1
  ok   the refusal names the fault
  ok   the help names the mend
  ok   nothing was committed
  ok   the unredacted row did not reach git
the seat can ask the question directly
  ok   filter-check answers 1 while the filter is unseated
  ok   filter-check answers 0 once setup has seated it
a path with no filter attribute still ships
  ok   an ordinary path ships
the hourly clock seats it on a seat where no hand ran setup
  ok   bin/vault/home-sync-clock.sh seated the filter without a hand
all cases hold
```

The test builds a real home — its own `.gitattributes`, its own filter script, its own bare remote —
ships the spine through `home-sync.sh ship`, and reads the committed blob back. Nothing touches
this machine's home.

The clock's own test still passes: `bash bin/gates/tests/test_home_sync_clock.sh` → `5 passed, 0 failed`.

## What is still owed (and by whom)

Seating is a **home** action, so this branch does not run it here: on this seat the filter was
already seated by hand last night (`git config --get filter.gna-redact.required` → `true`). Every
other seat gets it from the clock, or immediately with
`bin/vault/home-sync.sh setup`. A seat that ships the spine before either will now be **refused**,
not silently exposed.

## Files

- `bin/vault/home-sync.sh` — `seat_redaction`, `check_filtered`, the ship refusal, `filter-check`
- `bin/vault/home-sync-clock.sh` — seats the drivers at every hourly run
- `bin/vault/tests/test_home_redaction_filter.sh` — all four cases, end to end
- `bin/mail/README.md` — the privacy line corrected, and a change-log entry appended
