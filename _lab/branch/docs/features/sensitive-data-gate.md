# The sensitive-data gate

**What it is.** One gate every external surface passes through for a sensitive artifact
set: classification and hold, provenance verification, NDA/private guard, and an access
log. Snotra's meeting records are the first consumer; the pattern is generic.

## Use it

```sh
bin/gates/guards/sensitive-gate.sh <meeting-dir> --surface private
bin/gates/guards/sensitive-gate.sh <meeting-dir> --surface trello
bin/gates/guards/sensitive-gate.sh <meeting-dir> --surface email --to a@example.com,b@example.com
```

Surfaces: `private`, `email`, `trello`, `chat`, `public`, `model`.

## What it checks

1. `classification.yaml` — `classification` and `hold`.
2. A patent/restricted/confidential class is refused on every non-private surface.
3. `provenance.json` — `verify` must pass for an external surface.
4. The NDA/private guard for Chat/public/model payloads.
5. An append-only `access.jsonl` (mode 0600) records actor, surface, recipients, verdict
   and reason.

## Wiring

- `snotra-trello.sh export` calls it before the export.
- `mail-send.sh draft --meeting-dir <dir>` calls it before building the MIME.
- A held meeting is refused; the refusal is logged.

## Limits

Local hash chain only; no qualified eIDAS timestamp, no WORM store, no off-host log, no
ACL yet. Those are plan 94.
