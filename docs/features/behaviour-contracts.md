# Behaviour contracts — is every system doing what it should?

A system can be installed and running and still not do its job. A behaviour contract does the real thing and says
whether it came back right.

## The commands

```bash
bin/ward/contracts.sh run              # every contract on this machine: ok, red or skip, each with one line
bin/ward/contracts.sh check --notify   # keep the reading, and tell the arm holder when one turns red
bin/ward/trouble.sh read --only contracts
bin/ward/trouble.sh fleet              # every machine's row, the contracts included
```

## The contracts

| Contract | Red when |
|---|---|
| nightly-renewal | Gróa's unit failed, Eir's last night failed, or no night ran for 26 hours |
| house-units | a user unit sits `failed` |
| review-once-per-head | one head was handed to review more than twice in 24 hours |
| arm-receipts | a Veil report waits more than 10 minutes for RECEIVED |
| well-recall | a recall from the well returns no episode |

Add one by writing `bin/ward/contracts.d/NN-name.sh`. It prints one line, `ok: …`, `red: …` or `skip: …`, and exits
0 or 1. Keep it read-only, and keep it under a minute.

## Gatus

To show the contracts on a Gatus board as well, set `GATUS_URL` and `GATUS_TOKEN` in your home's environment. Each
result is pushed to its external endpoint, `contracts_<host>-<contract>`.

## CHANGE LOG

- **2026-11-22** — written with the behaviour contracts (plan 350 F).
