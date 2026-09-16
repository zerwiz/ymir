#!/usr/bin/env -S uv run
# /// script
# dependencies = ["pydantic", "python-dotenv", "pyyaml", "rich"]
# ///
"""smidja Recon IV — long-running recon with interval checkpoints & context resets.

The shortcoming it fixes: a single scout session that runs half a million
tokens of recon starts forgetting its own early findings — pi's auto-compaction
frees SPACE, it never rescues RECALL. This smidja bounds the work instead:

  engineer(request)
      └─ recon_01 (scout)   → checkpoints scout_findings_01.md, runs fresh
      └─ recon_02 (scout)   → fresh window, seeded from the newest checkpoint
      └─ ...                → until the scout reports DONE
  synthesize (recon_orchestrator) → merges checkpoints → recon_findings_final.md
  document   (documenter)         → wraps the merged findings into the report

Usage:
    uv run smidja/smidja_recon_iv.py "<objective>" \
        --config <resolved roster config> [--max-intervals 5] [--interval-tools 25] \
        [--smidja-id X]

The scout checkpoints every ~interval-tools tool calls (prompting contract in
smidja/smidja_data/prompt_engineering/scout/system.md + the interval note below), so
a context boundary, a model switch, or even a power loss never loses the map:
the next session starts from the newest checkpoint file.

Run with one of the recon-interval rosters:
    smidja run --roster recon-interval-9b  "<objective>"
    smidja run --roster recon-interval-35b "<objective>"
    smidja run --roster recon-interval-orch "<objective>"   # Kaia-tier T2 synthesis
"""

import argparse
import json
import os
import sys
from pathlib import Path

from smidja_modules import agents, session, utils
from smidja_modules.data_types import (AgentCall, DocumentOutput, EventRecord,
                                    PhaseParams, ScoutOutput)

REQUIRED_AGENTS = ["recon_orchestrator", "scout", "documenter"]
DEFAULT_MAX_INTERVALS = int(os.environ.get("SMIDJA_RECON_INTERVALS", "5"))
DEFAULT_INTERVAL_TOOLS = int(os.environ.get("SMIDJA_RECON_INTERVAL_TOOLS", "25"))

INTERVAL_NOTE = """
## RECON INTERVAL NOTICE — the driver rotated your context window

You are starting interval {n} of a long recon. Your window was rotated to stay
sharp (or because it neared its ceiling). Your FIRST action: read the NEWEST
checkpoint(s) in {dir} — scout_findings_N.md (highest N = newest), then
running_summary.md — and continue the map from where they leave off. Do NOT
re-walk what they already cover; cite their paths and build on them.

Checkpoint discipline for THIS interval:
  - every ~{every} tool calls write `{dir}/scout_findings_{n}.md` with this
    interval's new findings (increment per interval),
  - keep `{dir}/scout_findings.md` write-through current (running full list),
  - refresh `{dir}/running_summary.md` — one page: top findings, still-unknown,
    next leads.
  - when the WHOLE recon is genuinely complete, add the artifact
    `DONE:complete` to your Report JSON so the driver stops the loop.

Now continue the recon described in the task below.
"""

SYNTHESIS_PROMPT = (
    "Recon objective: {ask}\n\n"
    "Consume the interval checkpoints in {dir} (scout_findings_N.md newest "
    "first, then scout_findings.md and running_summary.md). Merge them into "
    "one dense, citation-carrying final map: labeled findings, verified claims, "
    "and a clear list of what is still unknown. Write it to "
    "`{dir}/recon_findings_final.md` and list that file plus every checkpoint "
    "you merged in your artifacts. Return ScoutOutput with your summary "
    "describing how complete the map is."
)

DOCUMENT_PROMPT = (
    "Recon objective: {ask}\n\n"
    "Open `{final}` — the merged recon map — in full. Produce the final "
    "deliverable: a clean, operator-ready recon report (headings, per-area "
    "findings with cited paths, verification commands the reader can re-run, "
    "and an explicit 'unknowns / gaps' section). Copy the report into `docs/` "
    "with a descriptive slug (e.g. docs/recon_{smidja_id}_<area>.md) and list "
    "that path plus `{final}` in your DocumentOutput document_path / "
    "documented_files."
)


def newest_checkpoint(cdir: Path, max_chars: int = 6000) -> str:
    """Newest checkpoint content — the seed for a fresh scout window."""
    candidates = []
    for p in sorted(cdir.glob("scout_findings_*.md")):
        candidates.append(p)
    for name in ("running_summary.md", "scout_findings.md"):
        p = cdir / name
        if p.exists():
            candidates.append(p)
    best, best_mtime = None, -1
    for p in candidates:
        try:
            m = p.stat().st_mtime
        except OSError:
            continue
        if m > best_mtime:
            best, best_mtime = p, m
    if best is None:
        return ""
    text = best.read_text(errors="replace")
    return text[:max_chars] if len(text) > max_chars else text


def tool_call_count(run, phase_id: str) -> int:
    import sqlite3
    try:
        con = sqlite3.connect(f"file:{run.tracer.db_path}?mode=ro", uri=True, timeout=5)
        n = con.execute("SELECT COUNT(*) FROM events WHERE smidja_id=? AND phase_id=? "
                        "AND type='tool_call'", (run.smidja_id, phase_id)).fetchone()[0]
        con.close()
        return int(n)
    except sqlite3.Error:
        return 0


def drop_scout_session(run) -> None:
    """Force the next interval into a fresh scout window (checkpoint-seeded)."""
    run.agent_map.pop("scout", None)
    run._agent_map_path.write_text(json.dumps(run.agent_map, indent=2))


def main(ask: str, config: str = "smidja/smidja_smidja_config/smidja.config.yaml",
         smidja_id: str | None = None, max_intervals: int = DEFAULT_MAX_INTERVALS,
         interval_tools: int = DEFAULT_INTERVAL_TOOLS) -> int:
    cfg = agents.load_config(config)
    agents.validate(cfg, REQUIRED_AGENTS)
    run = session.ensure(cfg, smidja_id)
    cdir = run.context_handoff_dir
    ask_text = utils.resolve_prompt(ask)

    with run.phase(PhaseParams(name="request", kind="engineer", owner=run.engineer,
                               description="Capture the recon objective")) as ph:
        ph.log(input=ask_text)

    # ── interval loop: bounded scout runs, checkpointed + fresh-seeded ──────
    final = None
    done = False
    for i in range(1, max_intervals + 1):
        seed = ""
        if i > 1:
            seed = newest_checkpoint(cdir)
        note = INTERVAL_NOTE.format(n=i, every=interval_tools, dir=str(cdir))
        prompt = (f"CONTEXT RESET — seeded from the newest checkpoint:\n\n{seed}\n\n---\n\n"
                  if seed else "") + ask_text + "\n\n" + note
        with run.phase(PhaseParams(name=f"recon_{i:02d}", kind="agent", owner="scout",
                                   description=f"Recon interval {i}/{max_intervals} — "
                                               f"checkpoint every ~{interval_tools} tool calls")) as ph:
            scout = ph.call(AgentCall(output_type=ScoutOutput, prompt=prompt))
            tool_calls = tool_call_count(run, ph.phase_id)
        run.tracer.event(EventRecord(
            smidja_id=run.smidja_id, phase_id=run.phases[-1].phase_id, type="log",
            name="recon_interval",
            payload={"interval": i, "tool_calls": tool_calls,
                     "done_marker": bool(done)}))
        drop_scout_session(run)
        done = any(str(a).startswith("DONE:") for a in scout.artifacts) or \
               "DONE:" in scout.summary
        if done:
            break
    # a run that never got a scout envelope still worth a synthesize attempt

    # ── synthesize: recon_orchestrator merges the checkpoints ───────────────
    synth = None
    with run.phase(PhaseParams(name="synthesize", kind="agent", owner="recon_orchestrator",
                               description="Merge the interval checkpoints into the final map")) as ph:
        synth = ph.call(AgentCall(output_type=ScoutOutput,
                                  prompt=SYNTHESIS_PROMPT.format(ask=ask_text, dir=str(cdir)),
                                  previous=scout if scout is not None else None))

    # ── document: wrap the merged map into the deliverable ──────────────────
    with run.phase(PhaseParams(name="document", kind="agent", owner="documenter",
                               description="Wrap the merged recon map into the report")) as ph:
        doc = ph.call(AgentCall(output_type=DocumentOutput,
                                prompt=DOCUMENT_PROMPT.format(ask=ask_text,
                                                              final=str(cdir / "recon_findings_final.md"),
                                                              smidja_id=run.smidja_id),
                                previous=synth if synth is not None else None))

    return run.finish()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ask", help="recon objective, or a path to a .md prompt file")
    parser.add_argument("--config", default="smidja/smidja_smidja_config/smidja.config.yaml")
    parser.add_argument("--smidja-id", default=None)
    parser.add_argument("--max-intervals", type=int, default=DEFAULT_MAX_INTERVALS)
    parser.add_argument("--interval-tools", type=int, default=DEFAULT_INTERVAL_TOOLS)
    args = parser.parse_args()
    sys.exit(main(args.ask, args.config, args.smidja_id,
                  args.max_intervals, args.interval_tools))