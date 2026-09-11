#!/usr/bin/env -S uv run
# /// script
# dependencies = ["pydantic", "python-dotenv", "pyyaml", "rich"]
# ///
"""factory Prompt — the smallest factory: one agent, one prompt, traced end-to-end.

Usage:
    uv run factory/factory_prompt.py "<prompt or path/to/prompt.md>" [--agent builder] [--config factory/factory_factory_config/factory.config.yaml] [--factory-id a1b2c3d4]

Phases: engineer(request) -> <agent>
"""

import argparse
import sys

from factory_modules import agents, session, utils
from factory_modules.data_types import AgentCall, GenericOutput, PhaseParams


def main(prompt: str, agent: str = "builder",
         config: str = "factory/factory_factory_config/factory.config.yaml", factory_id: str | None = None) -> int:
    cfg = agents.load_config(config)
    agents.validate(cfg, [agent])
    run = session.ensure(cfg, factory_id)

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
    parser.add_argument("--config", default="factory/factory_factory_config/factory.config.yaml")
    parser.add_argument("--factory-id", default=None, help="join or pin an existing session")
    args = parser.parse_args()
    sys.exit(main(utils.resolve_prompt(args.prompt), args.agent, args.config, args.factory_id))
