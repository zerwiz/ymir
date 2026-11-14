# The jev doors were never down — the register was blind, and one door now stands

**2026-11-09 · component: model · `bin/model/jev-doors.sh` · `bin/model/tests/test_jev_doors.sh`**

The audit of the near loop found the jev rail "four doors registered, all four down". That was
true of the report and false of the machine. The doors were seated on the heart the whole time;
the register could not see them.

## Fault one — it asked a door that does not exist

```bash
[ -n "$HOST" ] || HOST="$(bash "$ROOT/bin/bridge/seat-host.sh" 2>/dev/null || true)"
```

`bin/bridge/seat-host.sh` is in no tree, at no commit. `HOST` was therefore always empty, every
URL was hollow (`http://:8099`), `curl` failed, and all four doors were painted **down**. A
registry that cannot name its machine is a fault of the registry, not evidence of four dead
doors — but the summary could not tell the two apart.

Now the host is resolved in a stated order, each step a door that exists: `JEV_DOOR_HOST` → a
`host:` line in the registry itself → the fleet registry's forge (else heart) → nothing. Nothing
means **`no-host`**, printed with the remedy and an exit of 3. The home's
`config/jev-doors.yaml` now names `host: heimdall` outright, so no seat depends on a machine
default.

## Fault two — it probed with a body the engine refuses

The probe posted `{"state":"x","questions":{"q":{"type":"noul","instructions":"ok?"}}}`. The
engine answers that with **400** (`questions.q: "criteria" must be a non-empty object`), and the
code counted only `200`. So even with a host, a door answering real traffic read as `down`.

The probe is now a valid question (a `choice` with descriptions **and** `criteria`), and the
answer is classified instead of collapsed:

```
states{code,meaning}:
  "200","up"
  "404","route-missing — the engine has no /v1/systemone (the rail's trunk build does this)"
  "400","up-refused-probe — the door is there, the question was malformed"
  "401/403","unauthorized — the key did not pass"
  "405","wrong-endpoint — something answers, but not this route"
  "501","not-a-decision-model"
  "503","loading"
  "000","down — silence, the only real 'down'"
```

An `up` door also reports the engine's build, so "which llama.cpp is answering" is never a guess.

## The third thing the audit learned: two engines, one route

- `llama-rail.service` (`b1-73c941b`, 0.4.1-dev, the fleet rail on `:8080`): **404** on
  `/v1/systemone`. It carries no decision route, whatever preset it is given.
- `~/.local/opt/jev/llama-server` (**b12138 / f7b41cca4**): carries the route. Measured live.

So a decision door must run the jev engine. Seated on the heart as user units, through one
wrapper that takes the key from the vault and never stores a value (`~/.local/bin/jev-door.sh`):

| door | port | unit | state |
|---|---|---|---|
| Julia-1 | 8099 | `jev-julia-1.service` | **enabled + active** — 168 MB, the triage loop keeps it warm |
| Kev-4B | 8098 | `jev-kev-4b.service` | seated, **not enabled** — raised, proved `200`, lowered |
| Laya | 8097 | `jev-laya.service` | seated, **not enabled** — not yet measured |
| OpenJev | — | — | no door: CC BY-NC 4.0, research only, never a commercial surface |

Not enabling the two larger doors is plan 201's lesson deliberately applied: four always-on
decision doors held 11.6 GiB of a 16 GiB card and starved a 35B coder.

## Measured (heimdall · A5000 16 GiB)

```
julia-1@q8_0  3 options: 127.2 ms median → 7.86 decisions/sec   input_tokens 57
julia-1@q8_0 12 options: 344.3 ms median → 2.90 decisions/sec   input_tokens 162
             answer: choice + probabilities + confidence, output_tokens 0 (no token generated)

the canonical case, "charged twice, wants the second charge back" → which desk?
  Julia-1  WRONG   shipping 0.61, and 0.85 on a repeat — never billing
  Kev-4B   CORRECT billing 0.89 (confidence 0.84), shipping 0.06, account 0.05
```

**The router is fast and wrong on the money question; the judge is right.** So Julia-1 may shape
and triage, but it must not be the only voice on a billing/shipping/account split — Kev-4B gates
it. This contradicts the vendor card's "billing 0.99 with descriptions" on this build and this
wording; recorded as measured.

The full record lives where the model-testing skill demands it: `backends-benchmark.md`
**§10.5.17** and `llamacpp/TESTING.md` **§8.8** in `$YMIR_HOME`. `~/.pi/agent/models.json` is
deliberately **not** touched — these are decision models on the `systemone` wire, not chat
models; registering them would offer pi an endpoint that answers typed questions and returns no
tokens. Said here so the omission is a decision, not an oversight.

## Guard

`bin/model/tests/test_jev_doors.sh` — **8 ok / 0 fail**: the script parses; the probe carries
`criteria`; the criteria-less body appears in no code; the states name `route-missing`,
`unauthorized` and `wrong-endpoint`; no call to a resolver that does not exist; a bogus host
never yields `up`; a portless door reads `no-door`; and, when the heart is reachable, the router
door reads `up` — otherwise the test says `skip` rather than borrowing a green it did not earn.

## Not done, named

Laya is seated but unmeasured. Kev-4B has one request, not a throughput sweep. The 12-option
accuracy sweep for Kev-4B is not run. No `ledger.jsonl` row: the seat carries no ledger file.

## CHANGE LOG

- **2026-11-09** — host resolution by named doors with a `no-host` state; the probe made valid
  and the states made specific; host named in the home registry; three decision doors seated on
  the heart with the key read from the vault at start; the measured numbers and the accuracy
  finding recorded in the skill's books.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine (this seat). The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
