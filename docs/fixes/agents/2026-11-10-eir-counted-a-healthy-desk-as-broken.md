# Eir counted a healthy desk as broken

**Date:** 2026-11-10 · **Component:** agents · **Door:** `bin/agents/eir-doctor.sh` (the surface loop)

## What was wrong

Every one of the twenty-six surfaces said `ok` and the header said **`broken 1`**. The counting was wrong,
not the machine:

```bash
case "$state" in
  unconfigured) unconfigured=$((unconfigured+1)) ;;
  *)            broken=$((broken+1)) ;;
esac
```

`mail` is the one surface that names its own state, and it speaks three words — `ok`, `unconfigured`,
`broken`. The catch-all counted the first of them as broken. The row said `ok` and the count said otherwise,
which is the worst shape a healer's report can take: a fault that is not there, on a line nobody reads twice.

## What was forged

```
    case "$state" in
      ok)           : ;;
      unconfigured) unconfigured=$((unconfigured+1)) ;;
      *)            broken=$((broken+1)) ;;
    esac
```

## Verified

```
$ bin/agents/eir-doctor.sh check
eir[1]{action,root,broken}:
  "check","/home/zerwizomar/ymir",0
```

## CHANGE LOG

- **2026-11-10** — found while fixing the security audit; the count and the rows now agree.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the heart's user. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
