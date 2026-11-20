# The council is seated by the install and the update, not only shipped by the repo

**Date:** 2026-10-20 · **Component:** `install` · **Plan:** 92 · **Rule:** 25 (a move/–a new
capability–is a migration), 66 §7 (a feature is done when the install seats it)

## The fault

The council of models shipped as an extension and a test suite, and **no install would ever
leave a roster behind**. A fresh machine would load `logretta_sit`, call it, and get
`no stack at <home>/config/logretta-stack.yaml` — a loud skip, and still not a feature.

That is plan 66 §7's exact failure: *a feature is not done when its code exists; it is done
when the install seats it.* It was caught by the Allfather's question, not by a test.

## The mend

| piece | what it does |
|---|---|
| `bin/pi/logretta-ensure.sh` | `status` · `ensure [--check]`. Seeds `<home>/config/logretta-stack.yaml` from `.agents/config/logretta-stack.example.yaml` **only when absent**; **never overwrites** an existing stack (its models are the operator's); validates with the extension's own parser (node `--experimental-strip-types`) so the seeded file is proven parseable, not merely copied |
| `bin/engine/ymir-install.sh` → `step_council` | runs beside `step_loaders`; reports `seeded` vs `already seated`; `--check` prints what it would do and writes nothing |
| `.agents/migrations/0010-logretta-stack.sh` | an EXISTING home is healed on update by `ymir-migrate` (which `ymir-install.sh` and `groa-update.sh` both call) |
| `bin/agents/eir-doctor.sh` → `council` | "is the council seated" is now a health surface; `fix` calls the ensure door |

## Verified

```
logretta.test.sh  · 25/25
  + an absent stack reports unhealthy
  + ensure seeds the roster from the template
  + a second ensure says "kept" — an existing stack is never overwritten
  + the seeded stack validates
  + an invalid stack reports unhealthy
bin/agents/eir-doctor.sh check   → "council","broken"   (correct on this home: no stack yet)
```

## Not done

The seeded roster names this repo's example models (`llama-swap/…`). A machine whose rail serves
different ids will validate but fail at the first sitting with `model not found` — the remedy is
named in `docs/features/the-council-of-models.md`'s troubleshooting table. Choosing the models per
machine is the Allfather's, not the installer's (Rule 07: nothing hardcodes a model for you).
