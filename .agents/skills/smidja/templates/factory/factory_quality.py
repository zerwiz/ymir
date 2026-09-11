#!/usr/bin/env -S uv run
# /// script
# dependencies = ["pydantic", "python-dotenv", "pyyaml", "rich"]
# ///
"""factory Quality — lint, typecheck, and build the project.

Usage:
    uv run factory/factory_quality.py "<reason for the quality run>" [--config factory/factory_factory_config/factory.config.yaml] [--factory-id a1b2c3d4]

Phases: engineer(request) -> code(quality)
"""

import argparse
import sys

from factory_modules import agents, quality, session, utils
from factory_modules.data_types import PhaseParams

REQUIRED_AGENTS: list[str] = []


def main(prompt: str, config: str = "factory/factory_factory_config/factory.config.yaml", factory_id: str | None = None) -> int:
    cfg = agents.load_config(config)
    agents.validate(cfg, REQUIRED_AGENTS)
    run = session.ensure(cfg, factory_id)

    with run.phase(PhaseParams(name="request", kind="engineer", owner=run.engineer,
                               description="Capture why quality verification was requested")) as ph:
        ph.log(input=prompt)

    with run.phase(PhaseParams(name="quality", kind="code", owner="quality",
                               description="Run the deterministic quality blocks")) as ph:
        result = quality.run_quality(run)
        passed = sum(1 for check in result.checks if check.passed)
        ph.log(passed=result.passed, checks=f"{passed}/{len(result.checks)}",
               artifacts=", ".join(result.artifacts))
        if not result.passed:
            raise RuntimeError("quality failed: " + "; ".join(result.failures))

    return run.finish()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prompt", help="inline text or a path to a prompt file")
    parser.add_argument("--config", default="factory/factory_factory_config/factory.config.yaml")
    parser.add_argument("--factory-id", default=None, help="join or pin an existing session")
    args = parser.parse_args()
    sys.exit(main(utils.resolve_prompt(args.prompt), args.config, args.factory_id))
