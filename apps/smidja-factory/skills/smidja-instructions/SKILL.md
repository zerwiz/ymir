---
name: smidja-instructions
description: "Turn a vague request into a great smidja instruction. Interview the user (ask questions), then write a request file the smithy can execute cleanly — with Where / Done means / Out of scope, and the right service/mode/chain. Use when the user asks to build/change/fix something and the ask is fuzzy, or when they want to 'send the smidja' / 'give it to the agents'. Write the ask, then hand it to smidja-start / smidja-launcher to launch."
version: "1.0"
allowed-tools: read, write, edit, bash, grep, glob
---

# Smíðja Instructions — ask first, then give the smidja something it can win

## Sibling skills — load one if the task matches

- **`smidja-start`** — how to actually launch the team you just picked
  (rosters, local/online models, chains, orchestrator, detached-launch gotcha).
- **`smidja-launcher`** — the one-command launcher (`scripts/smidja`): run, watch,
  audit, stop, learn, missions.
- **`smidja`** — smidja internals: cookbooks for install/create/update smidja and
  roster config.
- **`smidja`** — conventions when the work lands in `~/Ymir`.

The smidja executes a request file (`requests/*.md`) through an smidja chain
(builder, reviewer, orchestrator). A fuzzy ask produces a fuzzy run: agents
guess, review rejects, and Kaia has to triage. This skill fixes the input end —
**you interview the user, then write the instruction the smidja can execute
without asking questions.**

> The instruction file is what a builder with zero memory of this conversation
> will follow. If you would not give it to a contractor you had never met, it is
> not ready.

## When to use

- The user says: "build X", "add Y", "fix Z", "make the smidja do…",
  "give this to the agents", "send the smidja".
- The ask is a sentence or two — too thin for a builder.
- The user is unsure themselves and benefits from being walked through it.

## The workflow

### 1. Interview — ask the user questions

Do NOT start writing. Ask enough to fill these (most matter; skip only what the
user genuinely has no answer for):

| Question | Why it matters |
|---|---|
| **What exactly, in one sentence?** | The objective every agent and gate checks against. |
| **Where does it live?** | Repo + paths. The request must say *which repo* and the exact files/dirs. |
| **What does "done" look like?** | Verifiable: a build passes, a file exists with content X, a URL returns 200. Not vibes. |
| **What must NOT change?** | Out of scope: other files, other services, other repos, existing tunnels/configs. |
| **Any constraints?** | Stack, dependencies, no-new-deps, privacy, security, "don't touch prod". |
| **How much autonomy?** | Recon only (scout), small build (sdlc), full plan→build→review→docs (simple-sdlc), orchestrator with sub-agents, review-only. Also: how deep should Kaia's presence be — **T0** (none, tiny/throwaway runs), **T1** (admission notes, default for real work), **T2** (Kaia orchestrates the whole run). |
| **Which stack?** | Local (LM Studio/pi), cloud (opencode/ocrd), hybrid, free, or "you pick". This picks the service/roster. |

Ask them as a short back-and-forth, not a wall. Stop when the request would be
unambiguous to a stranger. One or two clarifying rounds is usually enough.

### 2. Pick the chain + service

Match the answer to the smidja surface (`smidja modes` / `smidja services`).
Standing reference for the stack: `docs/software-smidja-run.md`
(how to run) and `docs/SmidjaAgentsAndModels.md` (roster + model
backends — the source of truth for which agents/models exist).

**Key files (what they do):**
- `smidja/smidja_smidja_config/roster.yaml` — **the ONE smidja config file**: teams
  (named stacks: which agents + which model each runs + tools/writes;
  `--roster <name>` / `SMIDJA_ROSTER=<name>` pick one), agent roles
  (`role_defaults:`), and the model catalog (`tiers:` — role × backend tier;
  swap surface for `--model`, `SMIDJA_*_MODEL`, `SMIDJA_MODEL_TIER`).
- `justfile` — starter recipes from `~/Ymir`: `just scout/sdlc/simple-sdlc/orchestrate`
  run chains; `just sessions/phases/tail` watch them. It resolves the same
  `SMIDJA_CONFIG` / `SMIDJA_ROSTER` / `SMIDJA_MODEL_TIER` env vars.

| Work | Chain | Service hint |
|---|---|---|
| Read-only recon, "where is X" | `scout` | `local` or `cloud` |
| Small, well-understood change | `sdlc` | `local` (cheap) or `cloud` (reliable) |
| Big / fuzzy / needs plan first | `simple-sdlc` | `cloud` or `local-planner` |
| Review/audit an existing diff | `build-review` | `review` |
| Multi-agent coordination | `orchestrate` | `orchestrate` |
| Bench a model | `mission T1\|T2` | the roster under test |

When the user has no preference, default to **`local`** (LM Studio, no keys;
planner 35B / builder 9B / reviewer 12B) for cheap/air-gapped work and
**`cloud`** (deepseek-v4-flash via `ocrd`) when reliability beats cost. Check
`smidja modes` / `smidja services` for the exact presets — they are the current
source of truth. Note the choice in the request so the run is reproducible.

> **Before you launch: read the gotchas** in `smidja-start` (§7) and the
> evidence in `tests/local-models/RESULTS.md` — mostly: launch long runs
> detached (never through a short tool-call timeout), small local models may
> skip strict JSON reports, and reviewers must stay read-only.

### 3. Write the request file

Save to `requests/<slug>.md`. Structure:

```markdown
# <Title> — what, in one line

<1–3 sentence objective. The builder's contract.>

## What to build
1. <concrete, ordered steps; each verifiable>
2. …

## Where
- Repo: <path>
- Files/dirs it may touch: <exact paths>

## Done means
- <a check that can pass or fail, e.g. `npm run build` exits 0>
- <a file exists with expected content>

## Out of scope
- <what must NOT change — other repos, services, tunnels, prod, secrets>
```

Rules that make smidja requests work (learned from real runs):

1. **Every step is verifiable** — "write `repo-map.py`", not "make a tool".
2. **Done means is mechanical** — exit codes, file existence, HTTP status.
3. **Out of scope is explicit** — the builder's `writes` are wide; only the
   request constrains it.
4. **Name the repo absolutely** — the smidja runs from `~/Ymir`; a request
   for `~/CodeP/courses` must say so.
5. **Never put secrets in the request** — keys live in `.env`.
6. **One objective** — a request that tries to do three things makes three
   half-jobs. Split into separate requests if needed.

### 4. Launch it (or hand it over)

```bash
smidja run --service cloud "requests/<slug>.md"          # or the chain/service chosen
smidja run --mode local-planner "requests/<slug>.md" --kaia T2   # + Kaia orchestrates
# or, for a whole-stack pick:
smidja run --service <name> "requests/<slug>.md"
```

Default Kaia tier is **T1** (admission notes injected into every agent call —
no run is blocked). Use `--kaia T0` for throwaway/recon runs, `--kaia T2` when
the request is big enough that Kaia should orchestrate.

If the user wanted *you* to drive, load the **`smidja-start`** skill for
how to launch (detached tmux for long runs), watch (`smidja sessions` /
`just sessions`), and report the `smidja_id` + first phase. If they want to launch
themselves, tell them the exact command.

## What good looks like

The `requests/` files that produced clean smidja runs:

- `courses-astro-site.md` — full site, absolute repo, done-means + out-of-scope.
- `linuxcommand-tunnel.md` — infra task, ordered steps with the exact commands,
  "Done means: curl returns 200", "Out of scope: do NOT touch other tunnels".

Both were run start-to-finish by the smidja with no back-and-forth — that is
the bar. **If you would not hand the file to a contractor you never met, keep
asking.**

## Golden rules

1. **Ask before you write.** The interview is the product.
2. **The objective is one sentence.** Everything else hangs off it.
3. **Verifiable beats descriptive.** "exits 0" > "works correctly".
4. **Never assume the repo or paths** — ask or state them.
5. **Never commit secrets in a request** — they live in `~/Ymir/.env`.
6. **Note the service/chain** so the run is reproducible by anyone.