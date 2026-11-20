## snotra · unversioned · 2026-10-20 — private details redacted from public notes

### What

The fix notes for the meeting work carried the operator's name, address, company and
participants' names. Under Rule 04 those do not belong in this public repo, and under Rule
26 they must not ride an installer to another user.

The notes now name **the operator**, **a participant** and **the company**;
addresses are `operator@example.com`; the framework example and agenda template are
agnostic and ship with the skill.

### Why

A fix note is a public artifact. A reader of the repo — or a new installation — must learn
what changed, not who the operator's partners are. The specific record stays in the
private home.

### Verified

- `grep` for the operator's name, address, company and participant names outside the
  private home returns nothing in `bin/`, `docs/fixes/` or the shipped skill assets.
- The shipped framework example contains roles and rules, no names.

### Not verified

- Git history still contains the earlier text. Erasing history is a separate, destructive
  decision for the operator, not something a guard should do silently.
