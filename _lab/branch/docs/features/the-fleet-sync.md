# The fleet sync — your machines, one home

## What it is

**The fleet** is your own set of machines, joined over **Tailscale**, with **one home**
that stays current everywhere. Two jobs: raise what each seat *owes* (its role), and move
the operator's data between seats — **peer‑to‑peer, no central server, no relay**.

## What you need

- Ymir installed on each machine, and Tailscale up (the tailnet is the transport).
- A role per seat — `heart | forge | dev | hand` — so a seat raises only what it owes.

## Do it

**Move data between seats** (rsync over ssh, addressed by MagicDNS):

```bash
bin/fleet/tailscale-sync.sh status           # tailnet + configured peers
bin/fleet/tailscale-sync.sh init             # seed the config from its template
bin/fleet/tailscale-sync.sh push [peer]      # local → peer (all peers if omitted)
bin/fleet/tailscale-sync.sh pull <peer>      # peer → local
bin/fleet/tailscale-sync.sh --dry-run push   # show what would move
```

**Raise what a seat owes** (role‑gated; verifies after it acts):

```bash
bin/fleet/fleet-ensure.sh            # the heart's offices, the forge's stone, the dev stack
```

**See the shape:**

```bash
bin/fleet/topology.sh                # the fleet topology
bin/fleet/fleet-version.sh           # version across seats
```

## Notes and limits

- **Peer‑allowlisted.** Only the hosts in `config/tailscale-sync.yaml` may sync — there is
  no relay unless *you* add one.
- **Role correctness.** A seat raises exactly its roles; a body that ran the heart's
  record jobs would fork the chain.
- **Config is private.** The sync config is the operator's (`config/tailscale-sync.yaml`,
  from the tracked `.example`).
- **The vault rides rsync, not git** — its ciphertext is git‑ignored and moved by sync
  (see the vault page).

## If it does not work

| What you see | What to do |
|---|---|
| `status` shows a peer offline | Bring Tailscale up on that seat; check MagicDNS resolves it. |
| A push moves nothing | `--dry-run` first; the path may not be in the configured set. |
| A seat raised the wrong services | Fix its role (`bin/skuld/role.sh set <host> <role>`), then `bin/fleet/fleet-ensure.sh`. |
| The home diverges | Resolve on the seat and re‑sync; the mover never forces (it reports). |
