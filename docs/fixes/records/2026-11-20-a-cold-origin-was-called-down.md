# A cold origin was called down every half hour

**Date:** 2026-11-20 · **Component:** records (`bin/records/gimle-tunnels-check.sh`) · **Errand:** `tunnel-patience`

## What was wrong

The round rang the operator's phone again at 14:42:

```
[cron/HIGH] job failed (rc=1): bin/records/gimle-tunnels-check.sh --quiet — no output
```

Run by hand a minute later, two surfaces showed `000` — no HTTP answer at all — `documents` (AFFiNE) and
`desk` (the Gimlé MCP). Both answered within the minute: `https://affine.zerwiz.org/` returned `401` in
0.69 s and `https://mcp.zerwiz.org/` returned `404` in 0.29 s. From the rented host itself the MCP answered
`404` in 0.29 s, over IPv4 and IPv6 alike.

So nothing was down. The check allowed **ten seconds** for a cold origin, and AFFiNE takes longer than that
on its first request after idling. A monitor that announces a healthy surface as broken every half hour.

**The cause underneath the noise matters as much.** The cron runs from the pin (`~/ymir-runtime`), and the pin
was **182 commits behind `main`** — which is why a fix that merged hours earlier had changed nothing. The pin
was fast-forwarded the same hour (`ca7cf755` → `0ee9c408`), and the nightly NSR round, run from the pin
afterwards, reported `gates=5 passed=5 failed=0`.

## What was built

`gimle-tunnels-check.sh` now asks a second time when a surface returns nothing: a two-second pause, then a
twenty-five-second attempt. Only a second silence is a failure, and the row then reads
`000 after two tries` so the difference between *slow* and *absent* is visible in the table.

## The proof

```bash
$ bash bin/records/tests/test_tunnel_patience.sh
  ok   a host that never answers fails, and the row says it was asked twice
  ok   the check waited past the first timeout before judging
  ok   no public surface is a clean pass, not a failure
tunnel-patience: 3 passed, 0 failed
```

The blackhole is `192.0.2.1` (RFC 5737 TEST-NET-1): it resolves, and it never answers, so the retry path runs
for real and still fails honestly. Gate: `tunnel-patience`.

## What this does not decide

- **The pin is still a checkout, not a release.** `bin/engine/release.sh status` reports no releases and a pin
  that is a plain directory, so every "deploy" here is a `git pull` in place. That is plan 333's third phase.
- **AFFiNE's cold start is still slow.** The check is patient now; nobody has measured why the first request
  takes more than ten seconds, and a slow origin will still look slow to a person using it.

## CHANGE LOG

- 2026-11-20 — written the hour the alarm rang for a surface that was answering.

## Appended 2026-11-20 — the second alarm in the same burst: a rented host has its own road

`bin/fleet/registry-check.sh --quiet` failed at the same hour, and ran by hand it named exactly one
incoherence:

```
<a rented host>: state up but no tailnet name
```

The rule was *"state `up` means a tailnet name"*. That is right for the house's own machines and wrong for the
one that is **rented** and reached by its public address and an ssh alias — the row already carries
`"address"`, and never a tailnet name, because it is not on the tailnet. So the check called a naming
convention an incoherence every night.

It now requires **a road**, not a tailnet: `tailnet` or `address`. A row that names neither is still a finding,
and the message now says so (`state up but no tailnet name and no address — no road is named`).

```
$ bash bin/fleet/registry-check.sh
FLEET REGISTRY — coherent
  fleet.json · machines.yaml · services.yaml · hodd/machines/*/ all agree
```

Nothing in the home's registry was changed to satisfy the check: the row was right, and the rule was too narrow.
