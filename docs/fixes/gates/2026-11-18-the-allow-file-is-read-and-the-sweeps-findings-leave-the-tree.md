## gates · 2026-11-18 — the allow file is read at last, and the sweep's findings leave the public tree

The twice-daily private sweep queued **287** findings at 04:10 on 2026-11-18. Every one of them was
an `AGNOSTIC` finding from `bin/gates/agnostic-audit.sh`. Triage split them three ways: **36** were
real — this machine, its user names and the people of the house written into code, comments, tests,
templates and rules that ship publicly; **24** were false positives the house had either already
recorded as safe or never could have actioned; and **217** were historical entries in `docs/fixes/`,
whose redaction is the Allfather's decision (plan 287 §3, the callout "owed by the Allfather") and is
therefore **not** done here.

> [!IMPORTANT]
> The allow file was already the house's answer to a false positive — `hodd/config/private-scan-allow.txt`,
> one regex per line, each with its reason beside it, opened 2026-11-15. But the sweep's own regex
> rules were the only half that consulted it. Every finding the **engine** produced ignored the file
> entirely, so a documented false positive — the private-address detector that must spell a private
> address to recognise one — alarmed twice a day for ever, and the one real finding would have been
> lost in it. Two of them were already sitting in that file.

### What changed

| file | change |
|---|---|
| `bin/gates/agnostic-audit.sh` | reads the allow file (`--allow FILE`, or `YMIR_AUDIT_ALLOW`, default `<home>/hodd/config/private-scan-allow.txt`); a finding a rule matches is moved to an `allowed:` block and **still counted and printed**, never silent; `--paths-only` prints one `path:line` per finding and nothing else, so a job cannot read a prose block as a finding; the machine row gained an `allowed` field |
| `bin/time/nornir-job-private-scan.sh` | asks the engine for `--paths-only` and reads its machine row, instead of parsing the human report with a shape regex; its `allowed` count now includes the engine's |
| `bin/gates/tests/test_agnostic_audit.sh` | two new properties: a recorded reason clears the tree but is still counted and printed, an allow rule is **anchored** (a different path still fails); `--paths-only` prints paths and the one machine row, nothing else |
| `docs/features/agnostic-audit.md` | the two flags, the allow file and the `allowed` field, written for a person |

And the 36 real findings, each replaced by a role or a placeholder — no behaviour changed:

| where | what it said | what it says now |
|---|---|---|
| `.pi/extensions/constellation/*.test.ts` | a fixture card named this fleet's heart | `heart-a` |
| `bin/fleet/registry-check.sh` | the heart's check keyed on one machine's **name** | keyed on the `heart` **role** from the fleet registry |
| `bin/agents/groa-agent/seat.sh` | a table of four machines and their update minutes | the minute is derived from the host's own name (a stable hash), so any fleet staggers |
| `tools/tickets-mcp/ledger.mjs` | the home's plan shelves listed by name | discovered: `hodd/plans` and every sub-shelf under it |
| `apps/hlidskjalf/src/styles/global.css` | a realm's colours keyed to one person | the block is gone; a realm's tint comes from the registry (`store.ts` already sets it inline) |
| `apps/hlidskjalf/src/gates/Cron.tsx` | two machines named in the panel | the seats answer for themselves |
| `tests/test_utgard_box.sh` | the operator's home spelled as one machine's path | the runner's own `$HOME`, which is the same test on every box |
| `assets/reference/index.html`, `assets/Ymir.md` | a lore realm with the fleet's machine name in brackets | the lore realm alone |
| `.env.example`, `CONTRIBUTING.md`, `RULES/02`, `RULES/08`, `bin/agents/{pr-seal,seat-identity,name-registry}`, `bin/agents/groa-agent/*`, `bin/bridge/a2a-front.py`, `bin/collab/kit/docs/collaborator-door.md`, `bin/people/inbox.sh`, `assets/mock/mock.ts`, `.pi/extensions/{ymirhome,odrerir,skuld-branch-supervision}`, `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` | a machine, a user or a person named in prose, in a usage example or in a comment | the role (`the heart`, `the dev machine`), a placeholder (`<user>`, `<peer>`, `<seat>`) or the person's own description |

### Proof

The census, before and after, on the same tree:

```
before   findings: 287 in 165 file(s)      allowed: 0
after    findings: 217 in 123 file(s)      allowed: 22
```

All 217 that remain are `docs/fixes/` history (`git ls-files | grep '^docs/fixes/'`), and all 22 that
are allowed carry their reason in the home's allow file. The engine's own canary passes:

```
$ bash bin/gates/tests/test_agnostic_audit.sh
...
PASS: a finding with a recorded reason does not fail the tree
PASS: the allowed findings are still counted and printed
PASS: the allowed block never prints the word either
PASS: the machine row keeps allowed out of findings
PASS: an allow rule is anchored on its own path
PASS: --paths-only exits 1 on a finding
PASS: --paths-only prints paths and the one machine row, nothing else
test_agnostic_audit: every property holds
```

And the sweep itself, run with `--report` against a copy of the home, folds the engine's rows into its
queue and reports the allowed count in its run line.

### What is left, and whose decision it is

**217 findings in `docs/fixes/`** — a machine, a user or a person's name inside the record of an
older change. They are records (`RULES/06`: appended, never rewritten), and plan 287 §3 asks the
Allfather whether an old fix note gets a dated correction or stays as history. Two precedents exist
(`7e645827`, `821387d2`), both on notes that were still in flight rather than on history. **No fix
note was rewritten by this change.**

**One classification, also his:** one entry of the home's list is a `name:` for a word that is both
a figure of the lore and a machine of this fleet (the lore's dwarf-hall). The list's own guidance
says a machine named for a figure of the lore is `host:`. Reclassifying it would stop judging the word
in prose — which is most of the 46 remaining findings of that entry — and start judging it only where
it is used as a machine. Not done here: it changes what the ward refuses.

### Files

- `bin/gates/agnostic-audit.sh`
- `bin/time/nornir-job-private-scan.sh`
- `bin/gates/tests/test_agnostic_audit.sh`
- `docs/features/agnostic-audit.md`
- the 30 files named in the second table above

Found by `bin/time/nornir-job-private-scan.sh` (sweep 2026-11-18T04:10:13Z), fixed under the
`private-scan` errand. The home's side of the triage — the allow reasons, and the template's invented
entries removed from the deny list — is in `hodd/config/private-scan-allow.txt` and
`hodd/identity/public-deny.txt`.

## CHANGE LOG

- 2026-11-17 — review-mend: added missing heading for #816
