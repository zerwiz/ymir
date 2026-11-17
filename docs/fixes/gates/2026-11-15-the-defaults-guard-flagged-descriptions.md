# Fix — the defaults guard flagged descriptions, and blocked a six-PR batch

**What was wrong.** PR #771 (six PRs gathered into one) could not pass the gate: `defaults-guard` refused with
*"0 default(s), 9 unresolved"*. All nine findings were false:

- **six** were test files that DO assign their own home, but not at the start of the line — `export HOME=… YMIR_HOME=…`
  and `env YMIR_HOME=… cmd`. The ward's anchor (`^[[:space:]]*(export )?YMIR_HOME=`) only saw a line-leading
  assignment, so a deliberate fixture looked like a guessed home.
- **three** were files that only NAME `$YMIR_HOME` — a gate description, a probe string, a comment — and never read it.

**What was done.** The ward reads an assignment **wherever it sits on the line** (`(^|[[:space:];])`), keeping the
self-assignment exclusion, and it honours a named exception: a file carrying `# defaults-guard: prose-only` is one that
mentions the variable without reading it. The three files that only name it now carry that line with its reason.

**Also mended here (real, not a false positive).** `bin/forge/finding-log.sh` and `bin/forge/finding-tally.sh` loaded
the resolver and then read `${YMIR_HOME:-}` without asking it — they now call `ymir_home_root`, which is what every other
door does.

**Proof.** `bin/gates/guards/defaults-guard.sh check` on the branch: `0 default(s), 0 unresolved` (was 9). The ward still
refuses a genuine guessed home — the self-assignment case is still excluded, and `docs/fixes/` keeps the rule it enforces.

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #813
