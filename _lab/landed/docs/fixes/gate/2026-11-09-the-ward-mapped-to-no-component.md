# The ward mapped to no component

**Date:** 2026-11-09 · **Component:** gate · **Door:** `bin/gates/guards/fixes-guard.sh` (`path_component`)

## What was wrong

`path_component` had no row for `bin/ward/*`. A fix to the hound — its senses, its units, its
switch — mapped to **no component**, so a correct note under `docs/fixes/ward/` covered nothing:
the gate passed while saying it could not tell what the range touched. That is the same defect
the `bin/forge/*` row fixed on 2026-11-06 and the `bin/skuld/*` row fixed on 2026-10-12, found a
third time while shipping the guardian's on/off switch.

## What was forged

```
    bin/ward/*|.agents/tests/garmr.test.sh) echo ward ;;
```

Now the ward's own tests are covered by a ward note too.

## Verified

```
$ bin/gates/guards/fixes-guard.sh --check     # a ward note covers a bin/ward/* range
```
