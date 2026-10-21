# 27 — The documents are checked, not trusted

**Appended 2026-10-21**, at the Allfather's word: *"we need to validate that everything for users to
read in the readme are current functional and implemented. or have the readme become stale? … we
must make a rule for keeping documentation up to date."*

**Why it exists.** On that day the README told a user the smithy's npm name "was accepted twice by
the registry and served never" — while `npm view @zerwiz/smidja` answered **0.1.1**. It named
`docs/plans/README.md` <!-- stale-ok: quoted as the stale claim this rule was written for --> for the plan
index, which had moved into the vault. It pointed at
`docs/masterplan.md` <!-- stale-ok: quoted as the stale claim, not as a live path -->, which is
private and never shipped. It described `config/cron.yaml` as if a
clone held it, when a clone holds only `cron.yaml.example`. **Five instructions, five closed roads,
and not one of them looked wrong while reading.** That is the failure this rule is for.

A reader cannot audit a document. The author can, and does not, because the document was true when
it was written. So the checking must be automatic, and it must fail the push.

```
doc_law[7]{rule,what_it_means}:
  "A CLAIM ABOUT THE TREE IS CHECKED BY A MACHINE","every path, package and command a user-facing document names is verified by a gate — not by the author's memory and not by the reviewer's eye"
  "THE CHECK IS A WARD, NOT A MOOD","`bin/gates/checks/readme-claims.sh` runs inside `bin/gates/guards.sh` as `docs-claims-guard`; a stale instruction cannot be pushed, and it cannot be merged by habit"
  "A WAIVER IS WRITTEN, WITH ITS REASON","a line that names something deliberately absent carries `<!-- stale-ok: why -->`, or the token is listed in `docs/README-claims.waived`. An unwritten exception is drift"
  "THE PAGE MOVES WITH THE CODE, IN THE SAME CHANGE","a command, flag, port or path that moves updates its page and its `FEATURES.md` row in the same commit (Rule 14)"
  "BUILT OR PLANNED IS SAID OUT LOUD","a figure or feature that is not built says *planned*. A status, once earned, is corrected in place — and the correction is dated"
  "THE PRIVATE HALF IS NAMED, NOT LINKED","a document that lives in the vault is referred to by its path in the vault, never by a repo link that resolves to nothing"
  "A CHECK THAT CANNOT FAIL IS NOT A CHECK","the ward is proved by breaking a claim: a missing path, a dead package, a broken port. Every new check ships with the failure it catches"
```

## What is checked, and what deliberately is not

```
scope[3]{surface,checked,not_checked}:
  "README.md","paths, `@zerwiz/*` packages, and with `--ports` what actually listens","prose, tone, history"
  "docs/lore.md","paths a figure's entry names","whether a myth is well told"
  "FEATURES.md","paths and packages in each row; the page each row points at must exist","whether a feature is *good*"
  "docs/features/*.md","the same, and every command it tells a user to run should exist","the advice inside"
```

The gate cannot tell whether a sentence is **true in spirit** — only whether the road it names is
open. That limit is stated here so nobody mistakes a green ward for a finished document.

## Enforcement

- **`bin/gates/checks/readme-claims.sh`** — the checker (`--npm` for the registry, `--ports` for a
  listener report, a file list or README by default).
- **`bin/gates/guards/docs-claims-guard.sh`** — the ward, in `guards.sh`'s `WARDS` list, covering
  `README.md`, `FEATURES.md`, `docs/lore.md` and every `docs/features/*.md` page.
- **Rule 14** (a feature has a page and a row) and **Rule 06** (append, never rewrite) still hold:
  this rule adds *currency* to them, it does not replace them.

## The duty, in one sentence

**If a user can read it, a machine has checked it — and if it names a road, the road is open.**
