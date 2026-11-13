## agents · 2026-11-14 — every message to an agent says where it came from

### Why

The Allfather: *"when talking to eindris we need to tell where the message is coming from — herdr panes, rödd,
bifrost, terminal, etc."* A worker reading a bare line could not tell his voice from a script or from another worker.

### What changed

`bin/agents/msg-origin.sh` makes the stamp: `[from <who> · <road> · <machine>] <text>`. WHO comes first and says
plainly whether it is the Allfather, an agent, a person or a script: a worker read the helm's relayed line as the
Allfather's own word, so a place alone was not enough. Only a road that knows a person spoke writes "the Allfather".
The sender is, first match wins, `YMIR_MSG_FROM` (or `--from`), the herdr pane's agent (the helm when the pane is
the arm holder's, `$STATE/.arm.pane`), a person at a terminal, or the parent script. A line that already starts
with `[from ` is not stamped twice. The seat law in `bin/seat/herdr-run.sh` tells every worker how to read it.

| Road | Stamp |
|---|---|
| `bin/agents/eindri-send.sh` (18 callers) | automatic; `--from "<who>"` names the sender; `YMIR_MSG_STAMP=0` sends bare |
| Rödd's `steer_worker` (`bin/voice/voice_tools.py`) | `the Allfather, by voice through Rödd` |
| `bin/agents/eindri-notify.sh` | `agent <its --from name>`, through the door (was a hand-made `[name]`) |
| `bin/gates/nidhogg.sh` | `script Níðhöggr, the loop-breaker` |
| `bin/forge/review-seat.sh` | `script review-seat, Forseti door` |
| `bin/agents/domain.sh` | `script domain.sh, seating a domain` |

### Proof

From the helm's pane: `[from agent Hœnir (the helm, claude) · herdr pane w39:pT · heimdall] hello`; from the worker's:
`[from agent pi · herdr pane w39:pW · heimdall] hi`; from Rödd: `[from the Allfather, by voice through Rödd · heimdall] x`.
A stamped line passes through unchanged. Every edited script passes `bash -n`.

## Appended 2026-11-14 — the lease path, through its resolver

The new line in `bin/agents/eindri-notify.sh` read the lease from a literal `$HOME/Documents/ymirhome`
fallback, which is a guessed home (Rule 07). `defaults-guard` refused the push of the plan-275/283 branch
on it — the ward was right, and the fix is the house resolver the file already loads twenty lines above:
`STATE/.arm.lease` when the caller names the state, otherwise `ymir_home_root` from
`bin/vault/hoard-lib.sh`, and an empty `lease` when the home cannot be resolved (the next line already
falls back to the lock's own directory). `defaults-guard` now counts three defaults on this tree, with
this file's finding gone.
