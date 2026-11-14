## rules · 2026-11-14 — the repository is 100 % agnostic; the operator's own tooling lives in the home

### Why

The operator: *"it's critical that ymir's repo is 100% agnostic; our special tooling etc belongs in ymir home"* ·
*"it's a public repo and users might run their fleets in different ways"* · *"we need to have an audit of this running
on cron jobs twice a day."* An audit found real people's names, a company mail domain and one operator's host names in
code, prompts, tests and fix notes, and runbooks that assumed one fleet's layout.

### What changed

`AGENTS.md` gains a dated section stating the law; `RULES/04` (private shape, not only private data) and `RULES/25`
(no operator's fleet assumed; the audit on a clock) gain dated sections. The cleanup itself, the whole-tree audit and
its twice-daily schedule on the fleet's heart are the operator's plan, built as errands.
