# First-run setup for meetings — `snotra-init`

**What it is.** One idempotent command that gives a Ymir home the meeting skeleton:
the private meetings shelf, a starter operator file, a confidential register, the
framework and agenda templates, and the Snotra cron block.

It deliberately does **not** create a company, a participant, an NDA hash or a Trello
board — those belong to the operator.

## Use it

```sh
bin/time/snotra/snotra-init.sh check   # what is missing — no writes
bin/time/snotra/snotra-init.sh apply   # create it, idempotently
```

The installer runs `apply` as part of the `snotra` step, and the versioned migration
`0011-snotra-meetings` does the same for an existing home on `ymir-migrate apply`
(which Gróa runs after an update).

## What it creates

| Path | When |
|---|---|
| `hodd/life/meetings/` | always, if absent |
| `hodd/identity/operator.yaml` | only if absent — a blank template to fill in |
| `hodd/identity/confidential.yaml` | only if absent — empty protected list, markers, deny-by-default surfaces |
| `hodd/life/meetings/meeting-framework.md` | only if absent — the agnostic Þing framework |
| `hodd/life/meetings/templates/` | agenda, decision and sign-off templates |
| `config/cron.yaml` Snotra block | only if the marker is absent |

## What it cannot do

- It cannot know the operator's name, email or company; fill `operator.yaml`.
- It cannot connect Trello; run `mcp({ connect: "trello" })` and then
  `snotra-trello.sh export <meeting-dir>`.
- It cannot know an NDA; add each protected document's SHA-256 and the authorised
  addresses to the confidential register.
- It does not send mail or create a board.
