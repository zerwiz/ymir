# Two gates that could never pass — so every PR's checks were red

**2026-10-24.** Components: `bin/gates/capabilities.sh`,
`.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh`.

Found while diagnosing PR **#423**, whose gates job failed twice (pull_request and push) and which was reported as
"merge conflicts". The conflicts were real; the failures were not the PR's fault.

## Fault 1 — the capability register could not be generated at all

`bin/gates/capabilities.sh` ran a **command substitution inside an unquoted heredoc** and escaped its backticks for
a quoted one. bash then re-parsed them and answered:

```
bin/gates/capabilities.sh: line 178: bad substitution: no closing "`" in `
```

So `capabilities.sh` produced nothing, `capabilities --check` failed **every** run, and the gate `capability` failed
in CI forever:

```
"capability","FAIL","the capability register is current"
  capabilities --check: .agents/assets/agents/capabilities.md is STALE — run bin/gates/capabilities.sh
```

The remedy CI printed was advice that could not work: running the door failed the same way.

**Fix:** compute the extension-tool list in real code before the heredoc, quote the heredoc delimiter, and print the
list separately. The door now writes **599 door rows**.

## Fault 2 — governed paths with braces never matched

`compliance-check.sh` tested each governed path with `compgen -G`. Brace expansion (`{a,b}`) is performed by the
**shell before a command runs**, not by `compgen`, so a path written

```
apps/smidja-factory/{cookbooks,skills}/**
```

failed the test **while both directories existed**. Result:

```
"governed","governed paths resolve","FAIL","missing: apps/smidja-factory/{cookbooks,skills}/**"
```

**Fix:** detect a brace group, split it, and test each alternative. The gate now reports
`all 98 governed paths exist — PASS`.

## The third red, which was not a gate fault

A local `mocks` failure traced to an **untracked vendor tree** (`bin/time/snotra/container/…whisper/bindings/
javascript/package.json`, containing `"test": "echo \"todo: add tests\""`). It is not committed, so CI never saw it,
but it reddened every local run. It has been **moved**, not deleted, to `~/backups/snotra-container-2026-10-24` —
and its presence in `bin/` was itself the Snotra-in-the-time-doors fault this week is about.

## Proof

```
bin/gates/capabilities.sh                  -> wrote .agents/assets/agents/capabilities.md — 599 door rows
bin/gates/capabilities.sh --check          -> current (599 door rows)
compliance-check.sh                        -> 0 FAIL, rc=0 · "governed paths resolve","PASS","all 98 governed paths exist"
```

**The lesson, and it is the day's lesson again:** a gate that cannot pass is worse than no gate — it teaches every
hand to ignore the colour, and it hides the real failures behind a permanent red. Both of these were one-line
faults sitting in the way of every delivery.
