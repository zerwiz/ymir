## gates · 2026-11-11 — the canary lost its machine path, and the gate went red

### The fault

`bin/gates/tests/test_skills_mcp.sh` was failing on `origin/main` today:

```
$ bash bin/gates/tests/test_skills_mcp.sh
FAIL skills-share-guard.sh: the seeded canary is caught — rc=1 missed: machine path
skills-mcp tests: 1 failure(s)
```

The test seeds a canary skill whose ledger carries the things `skills-share-guard.sh` must
catch — an address, an email, a phone number, and a **machine path**. An earlier change
removed the literal `/home/...` from the seeded text, because a committed user path is a
Rule 07 fault in its own right. Both halves were right and together they were wrong: the
canary no longer carried anything for the guard's machine-path rule to catch, so the test
asserted a detection that had nothing to detect, and failed.

### The fix

The canary carries a placeholder `__MACHINE_HOME__/canary/bench`, and the test composes
`/home` into it at run time:

```sh
sed -i "s|__MACHINE_HOME__|/home|" "$CAN/shelf/bench-ledger/SKILL.md"
```

So no literal user path is committed (Rule 07 holds), and the seeded canary still carries a
machine path for the guard to catch (the assertion holds).

This work was found **uncommitted** in the `.yggdrasil/one-open-pr` worktree — staged,
never committed — while sweeping the box for work that had never left it. The sweep found
nothing else: every other dirty worktree held only regenerated `INDEX.md` / capabilities
files and merge temp files, and every branch ahead of main was already in main by squash.

### Verified

```
$ cd .yggdrasil/canary-machine-path && bash bin/gates/tests/test_skills_mcp.sh
ok   unit-template-check --quiet: the systemd unit template is readable by systemd
ok   skills-mcp.service: loopback only, and the health probe is documented
skills-mcp tests: 0 failure(s)          # origin/main: 1 failure(s)
```

## CHANGE LOG

- **2026-11-11** — Carved: the canary composes its machine path at run time, so the skills
  gate is green on main again without a committed user path.
