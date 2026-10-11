## gate · unversioned · 2026-10-11 — the mocks gate bit RULES/17's own vocabulary

### Why

The `mocks` gate greps the shipped runtime for `\b(mock|stub|placeholder|todo)\b`,
skipping comment lines — reasonable, since a header may explain *why* a guard exists.
But it also bit the vocabulary that Rule 17 makes **law**:

```
bin/gates/guards/dead-code-guard.sh:86:      consumer:*|ticket:*|todo:*) return 0 ;;
bin/gates/guards/dead-code-guard.sh:88:        printf '… (consumer: <who>) or what resolves it (todo: <section>)'\n' "$needle"
```

`consumer: <who reads it, outside this tree>` and `todo:<TODO.md section>` are the two
legal reasons in `dead-code.allow`, named in RULES/17 and implemented by that ward. One
line **parses** them; the other **teaches** them. A word that is a documented vocabulary
token is not a stub — but grep cannot tell a token from a deferral, so the gate had to
be told.

Measured 2026-10-11: those two lines were the only hits in the whole of `bin/`, and they
were the compliance row's red once the hoard ward stopped shouting.

### What

The exclusion demands the **pair** — a line carrying both `consumer:` and `todo:` — so a
lone `todo` in shipped code is still caught. Comments, `PUBLIC=`, and the vocabulary
pair are now the gate's three documented exclusions, each with its reason beside it.

### Verified

- `mocks` row → **PASS**, `bin/ clean`.
- **It still bites**: planted `bin/probe-stub-proof.sh` containing
  `echo "this is a placeholder implementation"` → the row went
  `FAIL … bin/probe-stub-proof.sh:2:echo "this is a placeholder implementation"`,
  naming the file and the line. Probe removed; `bin/` clean again.

A narrowed gate is only trustworthy if you show it still draws blood — that is the
measurement above, not the PASS.

### Files

- `.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` — the third exclusion
