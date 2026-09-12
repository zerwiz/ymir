# Project Skills — Every Skill a Project Should Have

> **Status:** Research-informed practice doc (`docs/research/`)
> **Based on:** the software-compliance research and working-with-agents research (see `docs/research/software-compliance-research.md` and `docs/research/working-with-agents.md`).
> **Applies to:** every Way-Of project following the NSR ruleset.

This document derives from the research **what skills every project must ship** in `.agents/skills/` — the deterministic scripted layer that turns a codebase into a software compliance. It answers: *what capabilities must `.agents/skills/` expose so agents are a leverage multiplier and the project stays reliable, portable, and safe.*

---

## 1. Why Skills (from the Research)

The core rule of the modern software compliance (disler/SSSF, Anthropic, practitioners):

> **Agents are bounded nodes; deterministic code owns the graph. Sequencing, retries, and acceptance live in code, and "agent proposes, code disposes."**

That "code" is the **skill layer**: each operation an agent might need is a pre-written, gated script under `.agents/skills/`. Research reasons this is mandatory:

- **Eliminate hallucinated commands.** "Left alone, an agent will confidently produce code that doesn't meet your standards." If every standard op is a script, there is nothing to hallucinate.
- **Token + cost control.** Move known work (tests, lint, run, deploy) into code phases so you "stop paying an agent to do arithmetic" (~4×–15× token multipliers otherwise).
- **Deterministic verification.** Gates judge output by exit code (`$? == 0`), not by LLM text. A skill is the unit that can be gated.
- **Back-pressure before review.** Linters/hooks inside the loop fix failures *before* the PR.
- **Standardized tooling** — one of the four observable properties of a working compliance (standardized inputs, tooling, measureable output, replayability).

---

## 2. The Mandatory Skill Domains (Every Project)

Every project MUST expose these domains under `.agents/skills/`. These are non-negotiable and come directly from the compliance loop `Signal → Triage → Plan → Build → Test → Review → Secure → Ship → Monitor`.

| Domain | Purpose | Required skills |
|--------|---------|-----------------|
| **lifecycle** | Predictable spin-up/teardown/health automation → the local & deployment loop | `start`, `stop`, `restart`, `status`, `smoke_test` |
| **git_ops** | Deterministic source control protected from ad-hoc, history-breaking commands | `create_branch`, `safe_commit`, `sync_upstream` (rebase + conflict check) |
| **testing** | Deterministic suites + fast post-implementation verification | `unit_test`, `integration_test`, `smoke_test` |
| **features/_<name>_** | Feature-isolated automation for every registered feature (no duplication, no ad-hoc) | `setup`, `test`, `smoke_test`, `rollback` (+ `seed`, `migrate` where applicable) |
| **compliance** | The embedded Agent Skill Compliance — harness, gates, config, telemetry | `SKILL.md`, `core_four.yaml`, `validate_code`, `verify_docs`, `runner`, `logger` |

> **Rule:** a project that lacks any of these domains is **not compliance-ready** (it sits at L2/L3 on the maturity ladder, not L4).

---

## 3. Detailed Skill Set per Domain

### 3.1 lifecycle
| Skill | Guarantee |
|-------|-----------|
| `start.sh` | Safe application spin-up; deterministic, no manual backgrounding |
| `stop.sh` | Graceful shutdown — **no raw `kill`** (research: bans `kill -9`, `pkill`, `taskkill`) |
| `status.sh` | Health check so the loop's Monitor phase has a signal |
| `smoke_test.sh` | Post-boot verification before accepting a run as healthy |

### 3.2 git_ops
| Skill | Guarantee |
|-------|-----------|
| `create_branch.sh` | Branch naming + ticket linking (consistent history) |
| `safe_commit.sh` | Runs pre-commit gates + formats message — the "agent proposes, code disposes" commit path |
| `sync_upstream.sh` | Rebase + conflict check — protects repo history |

### 3.3 testing
| Skill | Guarantee |
|-------|-----------|
| `unit_test.sh` | Fast unit suite (the cheapest feedback) |
| `integration_test.sh` | Cross-component verification |
| `smoke_test.sh` | Rapid post-implementation check — this is the back-pressure that runs *before* PRs |

### 3.4 features/_<name>_ (one dir per feature in FEATURES.md)
| Skill | Guarantee |
|-------|-----------|
| `SKILL.md` | Feature scope + script binding map |
| `setup.sh` | Environment/data bootstrap (deterministic DB state, mocks) |
| `test.sh` | Feature-isolated test suite (tenant-aware where applicable) |
| `smoke_test.sh` | Feature health verification |
| `rollback.sh` | Teardown / emergency rollback (research: every task packet carries a rollback) |
| *optional* `seed.sh`, `migrate.sh` | Deterministic data prep & migrations |

### 3.5 compliance — the embedded compliance skill
| Asset | Guarantee |
|-------|-----------|
| `SKILL.md` | Entry point definition for agent tools & capabilities |
| `config/core_four.yaml` | **Context / Model / Prompt / Tools** governing every agent phase |
| `gates/validate_code.sh` | Runs all gates; `$? == 0` decides |
| `gates/verify_docs.py` | Keeps STRUCTURE.md / FEATURES.md / HOSTING / DEVELOPER_SETUP / TECH_STACK in sync |
| `harness/runner.py` | Local execution harness & orchestrator loop |
| `telemetry/logger.py` | Token/cost/latency observability — "measure or you can't improve" |

---

## 4. The Cross-Project Standard Skills (From the Compliance Loop)

Beyond unit-level skills, the research points at **cross-cutting capabilities every project should expose**:

1. **Deploy skill** (`deploy.sh`) — env-driven rollout per target (env tier · client · tenant). Couples to `docs/CI_CD/deployment/` and `docs/HOSTING/`.
2. **Docs-sync skill** (`verify_docs.py`) — research: one of the compliance's observable properties is *replayability*; docs that drift break agents and on-call engineers. Always gated.
3. **Compliance-gates skill** — `check_env` (env-driven config), `check_paths` (relative paths only), `check_platform` (Mac/Linux/Windows portability). These are NSR's cross-platform / relative-path / env-driven rules turned into runnable skills.
4. **Install/harness skill** (`install.sh`) — a single command to deploy the compliance into any repo (SSSF: "the skill is the product", stamped via installer).
5. **Agent handoff schemas (envelopes)** — typed JSON/YAML so inter-agent context is structured, not conversational (`.compliance/harness/envelopes/`).
6. **Observability/telemetry skill** (`logger.py`) — every phase logs tokens, latency, tool calls, cost.

---

## 5. Why These Skills (Mapping to Research Findings)

| Research finding | Skill requirement it drives |
|------------------|------------------------------|
| "Zero ad-hoc shell commands" | Every op exposed as a script under `.agents/skills/` |
| "Deterministic gates judge by `$? == 0`" | `validate_code.sh`, `check_env/paths/platform.sh` |
| "Context transfers in code (typed envelopes)" | `.compliance/harness/envelopes/` schemas |
| "Agent proposes, code disposes" | `safe_commit.sh` (agent proposes message, code commits) |
| "Verification is the bottleneck" | testing + gates run *before* review; smoke tests on every change |
| "Match autonomy to blast radius" | deploy/rollback skills with human gates for production |
| "Cross-platform (Mac/Linux/Windows)" | `check_platform.sh`; POSIX lifecycle/git scripts |
| "Env-driven config; secrets never committed" | `check_env.sh`; `.env.example` templates |
| "Relative paths only" | `check_paths.sh` |
| "Repair, don't restart" | harness `runner.py` re-prompts same session on gate failure |
| "Telemetry or you can't improve" | `logger.py` feeding the embedded compliance telemetry stream |

---

## 6. The Minimal Viable Skill Set (Checklist)

Use this as the acceptance gate for "is this project compliance-ready?":

- [ ] `.agents/skills/lifecycle/` — `start.sh`, `stop.sh`, `status.sh`, `smoke_test.sh`
- [ ] `.agents/skills/git_ops/` — `create_branch.sh`, `safe_commit.sh`, `sync_upstream.sh`
- [ ] `.agents/skills/features/<feature>/` — `SKILL.md`, `setup.sh`, `test.sh`, `smoke_test.sh`, `rollback.sh` for **every** feature in FEATURES.md
- [ ] `.agents/skills/NSRcompliance/` — `SKILL.md`, `core_four.yaml`, `validate_code.sh`, `verify_docs.py`, `runner.py`, `logger.py`
- [ ] `.compliance/gates/` — `check_env.sh`, `check_paths.sh`, `check_platform.sh`, `check_danger.sh` (gate annotations), `check_wiring.sh` (stub vs wired)
- [ ] `.compliance/harness/envelopes/` — typed task/result envelope schemas
- [ ] `docs/CI_CD/deployment/deploy.sh` — env-driven deploy runner
- [ ] `.compliance/installer/` — `install.sh` to bootstrap the harness into any repo

---

## 7. Sources

- disler / IndyDevDan — Super Simple Software Compliance: https://github.com/disler/super-simple-software-compliance
- INDY DevDan breakdown: https://www.youtube.com/watch?v=haUfb1ievTE
- Anthropic — multi-agent orchestration: https://www.anthropic.com/engineering/built-multi-agent-research-system
- Cole Murray — software compliance guide: https://murraycole.com/posts/software-compliance
- mager.co — Software Compliance: The End Goal of Agentic Engineering: https://www.mager.co/blog/2026-03-19-software-compliance/
- Compliance.ai — Inside the software compliance: https://compliance.ai/articles/what-is-a-software-compliance
- Plannotator — what is an AI software compliance: https://docs.plannotator.ai/learn/ai-development/what-is-an-ai-software-compliance
- StrongDM — dark compliance: https://www.strongdm.com/blog/the-strongdm-software-compliance-building-software-with-ai
- TrueFoundry — agentic enterprise guide: https://www.truefoundry.com/blog/software-compliance-agentic-enterprise-guide
- GitClear — AI code quality research: https://www.gitclear.com/ai_assistant_code_quality_2025_research