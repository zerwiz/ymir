# The kit asks the project what it declares — a package.json with no `check` is not a failed doctor

**2026-11-07 · component: collab · `bin/collab/kit/scripts/checks.sh`**

## The fault

The kit's node lane assumed a repository with a `package.json` declares `check` and `typecheck` (and, at
push, `test`):

```bash
if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
  step npm run --silent check
  step npm run --silent typecheck
```

`npm run --silent <missing script>` answers **254**. So in a Node repository that declares other scripts and
not those three, the hook printed *"checks[doctor] refused: npm run --silent check failed"* — a refusal it
could not satisfy, on a project with nothing wrong.

Found by installing the kit into four repositories on 2026-11-07. Three have no `package.json` at all and take
the Elixir or skip lane (correct). The fourth, `Way-Of/Example5`, declares `build`, `dev`, `lint`, `start`
and the `db:*` scripts — **no `check`, no `typecheck`** — and would have had every commit refused.

This is the same class of fault the kit fixed on 2026-11-06 (when the hooks asked npm on any machine that had
npm); the per-repository `scripts/checks.sh` fixed the *tool*, not the *script*. A repository can declare the
tool and still declare none of the checks.

## The fix

One file. The node lane now asks the project's own `scripts` block what exists, and falls through when the
answer is nothing:

- `check` runs only when `package.json` declares it.
- `typecheck` runs only when `package.json` declares it.
- `test` runs only when `package.json` declares it.
- A `package.json` that declares none of them **falls through** to the next lane (Elixir, if `mix.exs` is
  there) and, failing that, to a printed skip that names the reason — *"this is a Node repository and its
  package.json declares no check or typecheck script"*.

The declared-script test reads `scripts` with `node`, with a `grep` fallback when node is absent. Nothing else
in the kit changes: the protected branch, the pull request, the fix note, the referee, the secret scan and the
private-data scan all stand.

## The measurements

Run against a scratch repository, one case per behaviour:

```
measured[4]{package_json,question,answer}:
  "no check, no typecheck","doctor","skipped — declares no check or typecheck script; exit 0"
  "check and typecheck that print","doctor","both ran in order; exit 0"
  "a check that exits 3","doctor","refused — check failed; exit 1"
  "no check, plus mix.exs, no mix installed","doctor","fell through to the Elixir lane: skipped, mix not installed; exit 0"
```

`bash -n` clean. The four repositories the kit was installed into were re-seated on this version.

## Owed

- The kit still has no lane for a shell-only repository (it prints the skip, which is honest). Naming one is a
  decision, not a default.

## CHANGE LOG

- **2026-11-07** — Carved. The node lane refused a `package.json` that declared a tool but not the three
  script names the kit assumed; it now asks the project and falls through when the answer is nothing.
