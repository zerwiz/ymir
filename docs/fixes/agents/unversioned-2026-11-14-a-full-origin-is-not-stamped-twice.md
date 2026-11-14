## agents · unversioned · 2026-11-14 — a full origin handed to the stamp is not stamped twice

### Why

The first report `fleet-truth-2` sent carried `--from "agent fleet-truth-2 (pi) · herdr pane
w39:p0 · heimdall"`, and `msg_origin` appended the road and the machine to it again, so the fleet
log recorded *"agent fleet-truth-2 (pi) · herdr pane w39:p0 · heimdall · herdr pane w39:p0 ·
heimdall"*. A stamp that repeats itself is not wrong about WHO spoke, but it is noise in the one
record the Allfather reads to tell his agents apart.

### What changed

`bin/agents/msg-origin.sh`: a caller that hands in a **full** origin is taken at its word — when
`who` already contains ` · ` it is printed unchanged. A bare `--from "agent <errand>"` still gains
the proved road and machine, so the ordinary road is untouched.

### Proof

```
$ YMIR_MSG_FROM="agent fleet-truth-2 (pi) · herdr pane w39:p0 · heimdall" bin/agents/msg-origin.sh --origin
agent fleet-truth-2 (pi) · herdr pane w39:p0 · heimdall
$ HERDR_PANE_ID=w39:pT YMIR_MSG_FROM="agent fleet-truth-2" bin/agents/msg-origin.sh --origin
agent fleet-truth-2 · herdr pane w39:p0 · heimdall
```

The second line is the important one: the pane came from the **proof** (`w39:p0`), not from the
inherited `w39:pT` it was handed.

### Files

`bin/agents/msg-origin.sh`.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #759
