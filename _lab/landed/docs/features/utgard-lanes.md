# Utgard lanes — best of N, and the board that compares them

## What it is

A **lane** is one brief sent to several boxes that differ in exactly one declared way. Each box runs the same factory
against the same words, and what comes back is a **board**: what each lane did, how long it took, what it cost, and
which one you would ship.

The point is comparison, not speed. Five cheap attempts at one problem usually beat one clever attempt, and the lane
that fails is often the cheapest information in the run.

Lanes do **not** run their model calls at the same moment. This machine's rail serves one model on one request stream,
so the lanes queue on a **lease** — parallel on files, serial on the model. Anything else thrashes the swap and pays a
model reload per lane, which is a slower and more expensive lie.

## What you need

- A box image: `bin/forge/utgard.sh box build`.
- A brief — one markdown file describing the work, exactly as you would hand it to one agent.
- One `--lane label=model[@where]` per lane, where `where` is `local` (this box's rail) or `tailnet` (another machine's
  rail). A tailnet lane needs `UTGARD_LANE_TAILNET_TARGET` set, because an address is never written into a script.
- For a lane that reaches a model: the one firewall rule `utgard box probe` prints.

## Do it

```bash
# three lanes: two harnesses, one different model
bin/forge/utgard.sh lane new sprint1 --brief task.md \
  --lane 'harness-a=qwen3.6-35b-a3b' \
  --lane 'harness-b=qwen3.6-35b-a3b' \
  --lane 'model-two=gemma-4-12b' \
  --ttl 4h --budget 200

bin/forge/utgard.sh lane run sprint1     # takes the lease, runs every lane in turn
bin/forge/utgard.sh lane board sprint1   # what each lane did, and the pick that is yours
bin/forge/utgard.sh lane list
bin/forge/utgard.sh lane rm sprint1      # revokes every door, reclaims every box
```

## What the axis can vary

In order of what is cheapest and most honest:

1. **The harness** — the skills, the tools, the phase prompts. The rail is the same, so the difference is yours.
2. **The model** — a workhorse against a frontier model, on the same brief.
3. **Where the model lives** — this box's rail, or another machine's over the tailnet. Different compute is a real
   difference, not a cosmetic one.

## Limits

- Lanes run **one after another** under one lease. That is the rail's shape, not an unfinished feature: one resident
  model, one request stream.
- A lane's board shows its **last line of output**, its wall time and its exit code — not a diff. The diff is in the box;
  `utgard box pull <lane-box> /box/work .` brings it home.
- `lane rm` removes everything, including a lane you wanted to keep. Pull first.
- A budget (`--budget N`) caps what the door will serve per box. Past the cap the door refuses with the number it
  stopped at, and the lane's board says FAILED.
- Nothing on the board merges itself. The board ends in your pick.

## If it does not work

- `refused: lane 'x' asks for a tailnet model, and no target is configured` — export
  `UTGARD_LANE_TAILNET_TARGET=host:port`; the address stays out of the scripts on purpose.
- `new: lane 'a' could not raise its box` — run the same `utgard box new` by hand to see the engine's own words.
- The board says `not run` — the lane never ran; `utgard lane run <name>` first.
- A lane answers 401 — the vault holds no rail key, so the door has nothing to inject.

## CHANGE LOG

- **2026-11-06** — Carved with plan 209's P3: the lane, the lease, the board, and the three axes a lane may vary.
