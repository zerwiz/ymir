# The kit runs only what a project declares — an Elixir repository is not a failed doctor

**2026-11-07 · component: collab · `bin/collab/kit/.githooks/{pre-commit,pre-push}` · `bin/collab/kit/docs/gates.md` · `bin/collab/standardise.sh`**

## The fault this closes

The kit's hooks asked `npm run check` and `npm run typecheck` (and, at push, `npm run test`) whenever **npm was
installed on the machine** — not whenever **the project declared the script**. On a workstation that carries
node for its own sake, that made the hook a lockout in every repository without npm:

- the three Elixir repositories the kit was installed into on 2026-11-07 (`Inmost-ControlTower`,
  `ForemanAI-Elixir`, `wayof-coe`) have **no `package.json` at all**;
- `ForemanAI` has one, and declares `build`, `dev`, `lint`, `start`, the `db:*` scripts — **no `check`, no
  `typecheck`**.

Measured, in every one of the four: `npm run --silent check` → `exit 254`, and `pre-commit` printed *"a ward
found a fault"* while no ward had been consulted. The first commit in each repository was refused by the kit
that had just been installed to help it.

A gate that cannot pass is not a gate. It teaches `--no-verify`, which is the exact habit the kit exists to
prevent.

## The fix

Both hooks now ask one question first — **does this project declare the script?** — and run only what it
declares:

```
declared[4]{script,when_it_runs}:
  "check","pre-commit *and* pre-push, only when package.json declares it"
  "typecheck","pre-commit, only when package.json declares it"
  "test","pre-push, only when package.json declares it"
  "everything else the hooks already did","unchanged — a protected branch, a branch with no pull request, and a behaviour change with no fix note"
```

The test is the `scripts` block itself (read with `node`, with a `grep` fallback), never the presence of npm.
A repository that declares nothing is not a repository that failed — it is a repository whose tree check is
somebody else's tool, and the fix-note and branch gates still stand over it.

`standardise.sh` version moved `1.0.0` → `1.0.1`; `kit/docs/gates.md` states the rule in the hooks table so the
next hand reads the behaviour before it reads the code.

## The measurements

From the branch that carries this fix, against the four installed repositories:

```
measured[4]{repo,declares,result}:
  "Inmost-ControlTower","nothing (no package.json)","pre-commit exits 0 — the baton check is the project's own gate"
  "ForemanAI-Elixir","nothing (no package.json)","pre-commit exits 0"
  "wayof-coe","nothing (no package.json)","pre-commit exits 0"
  "ForemanAI","package.json, no check/typecheck/test","pre-commit exits 0; the project's own lint stays its own"
```

`bash bin/collab/tests/test_collab.sh` — **22 passed, 0 failed**.

## Owed

- The kit still has no Elixir tree check of its own. Where a project declares none, the hook is silent; naming
  an elixir lane (`mix format --check-formatted`, `mix precommit`) is a decision for the CoE, not a default the
  kit invents.

## CHANGE LOG

- **2026-11-07** — Carved. The kit's hooks asked npm instead of asking the project, and refused the first
  commit in the four repositories it had just been installed into. Both hooks now run only what a project
  declares; version 1.0.1; 22 tests green.
