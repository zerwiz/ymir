#!/usr/bin/env -S uv run
# /// script
# dependencies = ["pydantic", "python-dotenv", "pyyaml", "rich"]
# ///
"""smidja Orchestrate (variant A) — Kaia dispatches sub-agents, tracks them, reports.

Usage:
    uv run smidja/smidja_orchestrate.py "<prompt or path/to/prompt.md>" [--config smidja/smidja_smidja_config/smidja.config.yaml] [--smidja-id a1b2c3d4]

Phases: engineer(request) -> orchestrator (Kaia, dispatches sub-agents) -> reviewer [-> revise ...]

The orchestrator agent gets the WHOLE task. It spawns sub-agents (scout,
planner, builder, reviewer) via its subagent_* tools, tracks their progress,
and returns an OrchestratorOutput envelope with every changed file. The gate
`orchestrator_dispatched` verifies it actually used the subagent tools — the
anti-hallucination guard for the coordinator role.

Like build_review, a rejection does not fail the phase; it fails the run after
the bounded revise loop.
"""

import argparse
import sys
from pathlib import Path

from smidja_modules import agents, gates, session, utils
from smidja_modules.data_types import (AgentCall, OrchestratorOutput,
                                    PhaseParams, ReviewOutput)

REQUIRED_AGENTS = ["orchestrator", "reviewer"]
MAX_REVISION_LOOPS = 3
KAIA_MEMORY_URL = "http://127.0.0.1:4602"


def kaia_memory_for(project: str, k: int = 5) -> str:
    """Recall Kaia's remembered lessons for a project from the engram bridge."""
    import json
    import urllib.parse
    import urllib.request

    try:
        url = f"{KAIA_MEMORY_URL}/recall?q={urllib.parse.quote(project)}&k={k}"
        with urllib.request.urlopen(url, timeout=3) as r:
            data = json.load(r)
        hits = [hit["episode"]["content"] for hit in data.get("results", [])]
        return "\n".join(f"- {h[:300]}" for h in hits) if hits else ""
    except Exception:
        return ""


def main(prompt: str, config: str = "smidja/smidja_smidja_config/smidja.config.yaml", smidja_id: str | None = None) -> int:
    cfg = agents.load_config(config)
    agents.validate(cfg, REQUIRED_AGENTS)
    run = session.ensure(cfg, smidja_id)

    with run.phase(PhaseParams(name="request", kind="engineer", owner=run.engineer,
                               description="Capture the incoming ask")) as ph:
        ph.log(input=prompt)

    project = Path(run.repo_root).name
    kaia_mem = kaia_memory_for(project)
    dispatch = (
        f"OBJECTIVE (the original ask, unchanged):\n{prompt}\n\n"
        f"PROJECT: {project}\n"
        f"WHAT YOU REMEMBER ABOUT THIS PROJECT:\n"
        f"{kaia_mem if kaia_mem else '(no prior memory yet — first run)'}\n\n"
        "Dispatch sub-agents to do the work, guided by your memory of what has "
        "worked or failed on this project before. Track them, then report every "
        "changed file.")

    with run.phase(PhaseParams(name="orchestrate", kind="agent", owner="orchestrator",
                               description="Kaia dispatches sub-agents, tracks them, and reports every changed file")) as ph:
        previous = ph.call(AgentCall(output_type=OrchestratorOutput, prompt=dispatch,
                                     gates=[gates.orchestrator_dispatched,
                                            gates.diff_matches_claims]))

    review = None
    for i in range(1, MAX_REVISION_LOOPS + 1):
        with run.phase(PhaseParams(name=f"review_{i}", kind="agent", owner="reviewer",
                                   description="Rule on every requirement in the spec, against the code on disk")) as ph:
            review = ph.call(AgentCall(output_type=ReviewOutput, prompt=prompt,
                                       previous=previous,
                                       gates=[gates.artifacts_exist,
                                              gates.verdict_consistent]))

        if review.approved:
            break
        if i == MAX_REVISION_LOOPS:
            break

        with run.phase(PhaseParams(name=f"revise_{i}", kind="agent", owner="orchestrator", retries=1,
                                   description="Kaia closes every blocking finding the reviewer named")) as ph:
            previous = ph.call(AgentCall(output_type=OrchestratorOutput, prompt=prompt, previous=review,
                                         gates=[gates.orchestrator_dispatched,
                                                gates.diff_matches_claims]))

    return run.finish(accepted=review is not None and review.approved,
                      reason=f"the reviewer never approved after {MAX_REVISION_LOOPS} revision(s)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prompt", help="inline text or a path to a prompt file")
    parser.add_argument("--config", default="smidja/smidja_smidja_config/smidja.config.yaml")
    parser.add_argument("--smidja-id", default=None, help="join or pin an existing session")
    args = parser.parse_args()
    sys.exit(main(utils.resolve_prompt(args.prompt), args.config, args.smidja_id))