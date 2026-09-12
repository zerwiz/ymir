#!/usr/bin/env -S uv run
# /// script
# dependencies = ["pydantic", "python-dotenv", "pyyaml", "rich"]
# ///
"""smidja Prompt — the smallest smidja: one agent, one prompt, traced end-to-end.

Usage:
    uv run smidja/smidja_prompt.py "<prompt or path/to/prompt.md>" [--agent builder] [--config smidja/smidja_smidja_config/smidja.config.yaml] [--smidja-id a1b2c3d4]

Phases: engineer(request) -> <agent>
"""

import argparse
import sys

from smidja_modules import agents, session, utils
from smidja_modules.data_types import AgentCall, GenericOutput, PhaseParams


def main(prompt: str, agent: str = "builder",
         config: str = "smidja/smidja_smidja_config/smidja.config.yaml", smidja_id: str | None = None) -> int:
    cfg = agents.load_config(config)
    agents.validate(cfg, [agent])
    run = session.ensure(cfg, smidja_id)

    with run.phase(PhaseParams(name="request", kind="engineer", owner=run.engineer,
                               description="Capture the incoming ask")) as ph:
        ph.log(input=prompt)

    with run.phase(PhaseParams(name="prompt", kind="agent", owner=agent,
                               description=f"Send the request straight to {agent} and parse its envelope")) as ph:
        ph.call(AgentCall(output_type=GenericOutput, prompt=prompt))

    return run.finish()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prompt", help="inline text or a path to a prompt file")
    parser.add_argument("--agent", default="builder", help="agent name from the config")
    parser.add_argument("--config", default="smidja/smidja_smidja_config/smidja.config.yaml")
    parser.add_argument("--smidja-id", default=None, help="join or pin an existing session")
    args = parser.parse_args()
    sys.exit(main(utils.resolve_prompt(args.prompt), args.agent, args.config, args.smidja_id))
