# Working with Agents — Comprehensive Guide for Way-Of Teams

> **Status:** Research-informed practice doc (`docs/research/`)
> **Based on:** software-compliance research — full sources in `docs/research/software-compliance-research.md`.
> **Companion:** `docs/research/agents-workflow.md` — the day-to-day workflow this guide feeds into.
> **Applies to:** every Way-Of project following the NSR ruleset, and to how engineers + agents + automation cooperate.

This is the operating manual for working **with** agent systems: the mental model, the architecture, the verification discipline, the economics, and the guardrails — grounded in the software-compliance research. The workflow *process* is documented separately in `docs/research/agents-workflow.md`.

---

## 1. What You Are Actually Building

A **software compliance** is an agentic system that takes a specification and produces working, deployed, tested software with minimal intervention. It is **not** a chat — it is a **continuous feedback loop**:

> "A pipeline runs once. A compliance learns." — mager.co

There is a **maturity ladder** (widely adopted, from mager.co / Dan Shapiro):

| Level | What it is |
|-------|-----------|
| **L0** | Autocomplete |
| **L1** | Chat-to-code |
| **L2** | File-aware coding agents |
| **L3** | Multi-agent pipelines |
| **L4** | Software compliance — autonomous build-test-deploy loops |
| **L5** | "Dark compliance" — no human on the floor (Fanuc lights-out model) |

A key distinction: an **AI compliance** (NVIDIA) manufactures *tokens* on GPUs. A **software compliance** **spends** tokens to produce software. Don't conflate the two.

**In NSR terms** the ruleset is designed to operate at **L4** (with L5 guardrails): deterministic harness owns the process, agents are bounded workers, gates decide acceptance, and telemetry feeds the loop.

---

## 2. The Three-Actor Model: Engineer, Code, Agents

From disler/IndyDevDan's Super Simple Software Compliance, keep **three actors** separate and use each at the right moment:

| Actor | Strength | When to use |
|-------|----------|-------------|
| **The Engineer (you)** | Defining intent, trade-offs, review, approval | Start (scope/acceptance) and end (approve/merge) |
| **The Code (determinism)** | Tests, lint, migrations, git, arithmetic, orchestration | Whenever the step is *known* — never pay an agent to do arithmetic |
| **The Agents (LLMs)** | Reading, deciding, drafting, exploring unknown code | Steps needing judgment over unstructured content |

> "The trick is not running more agents. The trick is using all three at the right moment." — disler/SSSF

**Rule of thumb:** if the task can be a script (`test`, `lint`, `migrate`, `commit`), it **must** be a script — you "stop paying an agent to do arithmetic." Agents handle only what needs reading and deciding.

---

## 3. The Architecture: Deterministic Code Owns the Graph

> "Deterministic Python owns the graph. Coding agents are bounded nodes inside it. An ADW script owns sequencing, retries, and acceptance. Agents work inside named phases. Typed JSON envelopes carry context across the seams. Every event streams into SQLite while it is still happening. **Agent proposes, code disposes.**" — disler/SSSF

Break this down into concrete rules:

1. **Sequencing, retries, acceptance = code.** The harness (`.compliance/harness/runner.py`) or an ADW-style script owns the run, not the agent's whim.
2. **Agents are bounded nodes.** An agent works inside **one named phase**, produces its output, hands off — it never drives the whole run.
3. **Context transfers in code, not conversation.** Agents write reference files into a `context_handoff/` or emit a final valid-JSON response parsed against a typed output (an envelope); code persists it (`envelope.json`) and injects it into the next agent's prompt. This kills the "game of telephone."
4. **Agent proposes, code disposes.** An agent may *propose* a commit message on its envelope; the `git commit` **code phase** decides and writes. The agent never runs `git commit` itself.

**In NSR terms:** this is `.compliance/harness/envelopes/` (typed JSON/YAML handoffs), `.compliance/gates/` (`$? == 0`), `.agents/skills/` (every operation is a bounded script), and the "zero ad-hoc shell commands" rule.

---

## 4. Orchestrator–Worker: The Dominant Pattern

Anthropic's production multi-agent research system validated the dominant architecture:

> "An orchestrator-worker pattern, where a lead agent coordinates the process while delegating to specialized subagents that operate in parallel."

The orchestrator:
- Breaks a task into **bounded, typed subtasks**.
- Routes each to a specialized worker (architect, coder, reviewer, tester, documenter, deployer).
- Holds state and re-collects results.

**Critical caveats from Anthropic (design constraints, not optional):**

- Multi-agent systems use **~4× more tokens** than single chat; some architectures **~15× more**. Agents "burn through tokens fast."
- **"Most coding tasks involve fewer truly parallelizable tasks than research"** — do not fan out agents for the sake of it. Parallelize only genuine independent work.
- Each subagent needs: **objective, output format, tool/source guidance, and clear task boundaries**.
- Agents should write artifacts to the filesystem and pass **lightweight references** back (not giant context blobs).

**Cost control pattern:** move known work (tests, lint) into **code phases**; reserve agents for the judgment-heavy parts. This is exactly the disler design and the NSR rule "everything via scripts."

---

## 5. The Task Packet: Standardize the Unit of Work

Every agent gets a **compliance-ready task packet** (from Cole Murray's practitioner guide). In NSR this is the **typed envelope** (`.compliance/harness/envelopes/`) — if it doesn't fit the envelope, it isn't ready to dispatch:

| Field | What it holds |
|-------|---------------|
| **Objective** | What must be achieved. |
| **Non-goals** | Explicitly what it must NOT do. |
| **Context** | Pointers to files/slices — not the whole repo. |
| **Acceptance criteria** | How the result will be judged. |
| **Capabilities** | Allowed tools, scripts, and paths. |
| **Checks** | Which gates run against its output. |
| **Terminal states** | `complete` / `retry` / `no-op` / `escalate`. |
| **Evidence** | Artifacts and exit codes it must produce. |
| **Rollback** | How to undo if it goes wrong. |

Envelope example (disler, Pydantic-style):

```python
class EnvelopeBase:
    status: "success" | "fail"
    summary: str
    artifacts: list[str]
    notes_for_next_agent: str

class BuildOutput(EnvelopeBase):
    changed_files: list[str]
    commit_message: str   # consumed by the git commit code phase
```

---

## 6. Verification Is the Bottleneck — Not Generation

The consensus across practitioners (Cole Murray, StrongDM, Plannotator, Compliance.ai):

> Generation is cheap. **Your ceiling is how fast and how trustworthily you can verify output.** The bottleneck is almost always verification, not generation.

Operational consequences:

- **Gates verify claims, never predictions.** "Success must be earned. Every phase defaults to `fail`." — disler/SSSF
- Gate types: `artifacts_exist`, `files_non_empty`, `json_parses`, `diff_matches_claims`, `tests_pass(...)`. A gate is `gate(envelope, run) -> GateReport`.
- **The quality signal cannot be the same model that did the work.** An agent grading its own homework is too lenient. Use an independent deterministic check (tests, lint) or a different model.
- **Back-pressure before review.** Linters, hooks, and static analysis run *inside* the sandbox so agents see and fix failures **before** the PR — "Left alone, an agent will confidently produce code that doesn't meet your standards."
- **Visible failure is your friend; silent failure is the enemy.** A capped conversation, an unexercised test, a check that passed for the wrong reason — all silent failures. Make them loud.

**In NSR terms:** `.compliance/gates/` (check_env, check_paths, check_platform, verify_docs, validate_code) run before commit and before deploy, judged by `$? == 0`.

---

## 7. The Feedback Loop Makes It a Compliance

> "A pipeline runs once. A compliance learns." — mager.co

```
Signals → Triage → Plan → Build → Test → Review → Secure → Ship → Monitor → (new Signals)
```

Three loop behaviors matter:

1. **Repair, don't restart.** When JSON doesn't parse or a gate fails: *nothing restarts.* The harness **re-prompts the same session** with a correction naming exactly what was wrong, and the context window stays intact. One correction = one message, not a cold start.
2. **Monitoring feeds the queue.** Alerts/dashboards produce new signals that re-enter triage as tickets.
3. **Measure to improve.** "If you cannot measure your agents, you cannot improve them." Every event streams to the telemetry store (`logger.py` / SQLite) — phases, events, envelopes, gate results, agent sessions.

**Four observable properties of a working compliance** (Compliance.ai): standardized inputs, standardized tooling, measurable output, replayability.

---

## 8. Match Autonomy to Blast Radius

Trust is earned in stages (the trust ladder seen across Cursor, Stripe, Harvey, StrongDM):

| Blast radius | Suggested autonomy |
|--------------|--------------------|
| Read-only / research | Full autonomy |
| Draft PRs / low-risk code | Auto-generate, human review |
| Small scoped refactors, low-risk PRs | Auto-merge with gates + review |
| Production / per-client / multi-tenant deploys | Full gates **+ human go/no-go gate** |

> The field genuinely disagrees on whether review stays human or becomes automated — but the safe default is **match autonomy to blast radius.**

Industry-landscape reality check (self-reported numbers — treat as promotional, not comparable):
- Stripe: 1,300+ agent PRs/week, still human-reviewed.
- Cursor: ~40% of internal PRs.
- Uber Minion: ~11% of PRs.
- Ramp Inspect: >50% of PRs.
- Ona: 375 PRs in 10 days.
- StrongDM: runs a **dark compliance** (no human review; validate purely by observable behavior).
- Cost: ~$1,000/day per engineer in tokens (StrongDM-reported).

---

## 9. Guardrails: Costs, Loops, Credentials, Quality

| Pitfall | Mitigation (NSR) |
|---------|------------------|
| **Token explosion** (~4× chat, ~15× multi-agent) | Move known work into code phases; effort budgets per phase; parallelize only genuine independent work |
| **Agent loops / spiraling** | Bounded phases, retry caps, terminal states (`no-op`/`escalate`) |
| **Hallucinated commands** | Zero ad-hoc shell commands — all ops via `.agents/skills/` scripts |
| **Cost explosion** | Telemetry (`logger.py`), budgets, spend metering per phase |
| **Code-quality erosion / "velocity theater"** | Structural gates, review by risk tier, one primary stack per feature (GitClear: more duplicate code & churn as AI code grows) |
| **Credential exfiltration** | Secrets live in the control plane (`.compliance/`, env/secret manager) — never in the agent sandbox; secrets never committed |
| **Self-graded homework** | Gates + tests independent of the producing agent |
| **Prompt-injectable agents** | An agent that can be prompt-injected will eventually exfiltrate whatever credentials it can reach — keep credentials out of the sandbox |
| **Overstated maturity** | "Repeatable inputs do not guarantee good intent. More autonomy ≠ lower cost or higher quality." (Plannotator) |

---

## 10. Model Selection per Phase (Core Four)

> "It is not about which model is best anymore; it is about which model is right for that one phase." — disler/SSSF

- **Fast/cheap model** for coding, tool calls, routine edits.
- **Larger reasoning model** for planning, architecture, deep debugging.
- Configure in `core_four.yaml` (**Context / Model / Prompt / Tools**); the harness reads it per phase.
- Different models at different price/speed points can run **in the same run**.
- Agent roster declares: `model` (provider/model-id), `thinking` level, `purpose`, prompt files, tools, and a `writes` boundary (which files it may touch — a scope guard).

---

## 11. Seams & Infrastructure

- **MCP servers** standardize external tool access. Tool descriptions vary wildly in quality — centralize tool registration, auth, guardrails, and observability (NSR: `.compliance/` control plane; the embedded compliance skill's telemetry + WayOfTeams sync).
- **Agent/skill registries** index capabilities so agents can discover them (NSR: `.agents/skills/`).
- **Task queues / packets** are the standardized units of work entering the line.
- **CI/CD feedback loops** re-enter failing work; monitor alerts spawn incident agents.
- **Telemetry boundary**: agents write events; humans/dashboards poll them. One data path, no exceptions.

---

## 12. The NSR Working-with-Agents Playbook

A concrete, per-task checklist:

1. **Open an envelope** — objective, non-goals, acceptance, capabilities, checks, evidence, rollback (typed JSON/YAML).
2. **Check `FEATURES.md`** — is this already built? Don't duplicate.
3. **Route to a feature skill** — pick the phase and the feature's `.agents/skills/features/<feature>/` scripts.
4. **Let code own the run** — the harness sequences; gates decide (`$? == 0`); agents stay in their phase.
5. **Verify independently** — run gates + tests; another model or a deterministic check judges the result.
6. **Log it** — telemetry records tokens, latency, tool calls, cost for that phase.
7. **Review by blast radius** — dev loop can auto-merge; production requires the human gate.
8. **Feed the loop** — test failures re-trigger the same agent; incidents become new tickets.

---

## 13. One-Line Rules to Remember

- Agents read and decide; code sequences and verifies.
- If it can be a script, it must be a script.
- Context moves in envelopes, not conversation.
- Success must be earned; every phase defaults to fail.
- Verify with something independent of the producer.
- Autonomy = f(blast radius).
- Measure agents, or you can't improve them.
- Make failure visible.
- Repairs re-prompt the same session; they never restart cold.
- Vibe coding is not knowing how your system works, and not looking. Agentic engineering is knowing how your system works so well you don't have to look.

---

## 14. Sources

- disler / IndyDevDan — Super Simple Software Compliance: https://github.com/disler/super-simple-software-compliance
- INDY DevDan breakdown: https://www.youtube.com/watch?v=haUfb1ievTE
- Anthropic — multi-agent orchestration: https://www.anthropic.com/engineering/built-multi-agent-research-system
- Cole Murray — software compliance guide: https://murraycole.com/posts/software-compliance
- mager.co — Software Compliance: The End Goal of Agentic Engineering: https://www.mager.co/blog/2026-03-19-software-compliance/
- Compliance.ai — Inside the software compliance: https://compliance.ai/articles/what-is-a-software-compliance
- Plannotator — what is an AI software compliance: https://docs.plannotator.ai/learn/ai-development/what-is-an-ai-software-compliance
- StrongDM — dark compliance: https://www.strongdm.com/blog/the-strongdm-software-compliance-building-software-with-ai
- TrueFoundry — agentic enterprise guide / MCP gateway: https://www.truefoundry.com/blog/software-compliance-agentic-enterprise-guide
- GitClear — AI code quality research: https://www.gitclear.com/ai_assistant_code_quality_2025_research
- Wikipedia — Software compliance (history): https://en.wikipedia.org/wiki/Software_compliance