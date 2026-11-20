## ward · 2026-10-21 — the advisor rides the fast road, and coarsens before it leaves the box

### Why
The Allfather, on reading that the advisor defaulted to the small local summariser: *"the bite/counter
need a much faster and bigger model than this… many an online model, like opencode-go/deepseek-v4.1-flash
— fallback my 35B mtp."* He is right about the shape of the problem: a triage during an incident is a
**latency** question, and a 9B asked to reason about an intrusion is answering a question it is not
strong enough for.

### Fix
The advisor now has a **road**, configured in the guardian config:

```
hound:
  advisor_online: false                                    # ship safe: everything stays on the machine
  model_name:      opencode-go/deepseek-v4.1-flash         # fast + strong, when the road is allowed
  model_fallback:  llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp  # the Allfather's own 35B
```

- **Online first, the 35B second.** If the online road answers nothing, the local 35B triages instead,
  and the output says which road answered.
- **Coarsened before it leaves.** With `advisor_online: true` the metadata loses its map: a path becomes
  `<path:basename>`, a destination `185.220.*.*`, a unit `<unit>`. A vendor does not need our topology.
- **Still only the six, still no policy.** The allowlist and the armed classes are unchanged: an unarmed
  class is refused with the one line to edit, and the model still never acts.

### Verified
`bash -n` clean; the advisor answered through an injected stub and proposed `stop-unit` with the note
*"still needs a WRITTEN RULE — the advisor proposes, the rules dispose"*; `docs-claims-guard` green.

### Files
- `bin/ward/garmr-bite.sh`
- `.agents/config/garmr-rules.example.yaml` (the road, documented where the operator will look)
- `README.md`
