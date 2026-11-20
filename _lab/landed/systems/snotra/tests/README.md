# tests/ — the system's own gate

`smoke.sh` is Snotra's gate: it walks the pipeline's doors with three verdicts each (pass · skip · fail) and says
which one it got, so a break is named rather than felt. It ships WITH the system, so it moved with it.

```bash
systems/snotra/tests/smoke.sh                 # the whole gate
systems/snotra/tests/smoke.sh <meeting-dir>    # one meeting
```

A test lands here when it is **about this system** — a door's behaviour, a record's standard, a letter's gate. A test
that belongs to the wider runtime stays in `.agents/tests/`, and a check that belongs to the machine's health stays
an `*-ensure.sh`. New tests are added here with a name that says what they prove.
