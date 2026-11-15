# assistant · 2026-11-14 — Skírnir's values leave the code, and his tests ask the home for them

## Files

- `.agents/config/skirnir.yaml.example` — **new**: the shape of Skírnir's settings (the home already had the
  reader and no shipped shape, which RULES/42 calls a wish)
- `.agents/config/skirnir/vocab.txt.example` · `canaries.txt.example` — **new**: the shape of his word list and
  his own wall
- `.agents/home-contract.yaml` — three rows for those files
- `systems/skirnir/services/skirnir.py` — his subject aliases read from his settings; his own canary list read
  from his home, withheld from every tier but the owner; the room rule and the retrieval notes are generic
- `systems/skirnir/services/test-fixtures.sh` — **new**: the operator's own names, contact and two-fact subject,
  handed to a test so the test needs none of them
- `systems/skirnir/services/ear.sh` — the vocabulary hint comes from his home, then the house's own names
- `systems/skirnir/services/learn-site.sh` — the page is his setting, then Ymir's own public site
- `systems/skirnir/services/canaries.txt` — the one machine name leaves the public base list
- `systems/skirnir/services/smoke.sh` · `walls-test.sh` · `research-smoke.sh` — the assertions take their names,
  their contact and their subject from the home at run time
- `systems/skirnir/services/{asks,learn,query}.sh` · `research.py` · `test_brief.py` · `test_model_chain.py` ·
  `backup.sh` — example names and machine names replaced by invented ones and by roles

## Why

Plan 288 §1: what is generic is Skírnir's craft and stays in `systems/skirnir/`; what is about one operator —
his clients, his machines, his page, the phrasing that reaches his facts — belongs in his home. Measured before
this change: a client's name in his walls, his smokes and his research test; two people named in the NDA room
rule; a machine named in `canaries.txt` (a leak guard that published what it guards); a client and a project
name in the intent table; and a `config/skirnir.yaml` the code read while the repository shipped no shape for it.

The tests were the hard half: a test that asserts "no private name rode along" cannot carry the name in a public
repository. So one door, `test-fixtures.sh`, asks the home and hands the test its fixture — the same reader the
people-guard uses, so the ward and the test can never disagree.

## Fix

- **The rule is generic, the names are his.** The room rule reads *people with different grants in one room hear
  only what every one of them may hear*; which person holds which grant is his `hodd/identity/grants.yaml`. The
  NDA sentence that named two people now names none.
- **Fixtures at run time.** `test-fixtures.sh names|contact|subject`: his registered private names; a person held
  only as a contact (a name that appears in no claim a stranger may hear); a subject his digest holds two facts
  about. An empty answer is a printed clean skip, never a silent pass.
- **His settings have a shape at last.** `config/skirnir.yaml` (already read by `skirnir.py`), plus
  `config/skirnir/vocab.txt` and `config/skirnir/canaries.txt`, each shipped as a `.example` and named in the
  home contract.
- **His own wall is tiered honestly.** The repository's base list still binds everyone without exception; his
  own strings join the list that a stranger may not hear — so the owner may hear his own machines and an
  outsider may not. The one machine name that stood in the public base list left it and lives in his home.

## Verified

- `bash -n` on every touched door; `python3 -m py_compile systems/skirnir/services/skirnir.py`.
- `systems/skirnir/services/smoke.sh` with the home's config: **36 pass · 1 skip · 2 fail** against a measured
  baseline of **35 · 1 · 3** — no new failure, one mended (the Trello name resolve). The two that remain are not
  this change: `what is gimle` is answered from a home plan fact (`home-plan-158`), and `snotra-whisper` is not
  running on `:10300`.
- `systems/skirnir/services/walls-test.sh`: **9 failures** against a measured baseline of **10**; the only
  difference is `tie refusal`, mended by the home-derived subject. No failure is new (the pre-existing ones are
  the digest's own shape: the facts list, a learned statement, two escalation lines and a missing `ENGINE` export).
- The four unit suites against a home holding only the shipped shapes: `test_brief.py` 10 tests OK ·
  `test_mind.py` 20 OK · `test_model_chain.py` 6 OK · `adapter-test.sh` "the mouth holds".
- The private-word scan of `systems/` and `tools/snotra`: **43 findings before, 0 after**.
- `bin/gates/checks/home-contract-check.sh`: clean.

## Owed, named rather than hidden

- One approved fact is classed `public` and still names a client's contact person (it begins *"… led by its
  client …"* and then the person's name). A stranger therefore hears that name. Re-classing an approved fact is the
  operator's word, not a hand's; the smoke's contact fixture now avoids it, and this note records it.

## CHANGE LOG

- **2026-11-14** — note written; the split done under plan 288 §1, errand `systems-split`.
