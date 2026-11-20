# Fix note — Snotra reasoning integration, template rendering engine, email templates, and systems/ migration

**Component:** snotra
**Date:** 2026-10-31
**Plan:** 151

## What changed

1. **Reasoning adapter** (`reasoning_adapter.py`): LLM reasoning adapter supporting OpenAI, Anthropic, Google, and local (llama-swap). Implements extract, steps, dedup, classify, identity, test. Smoke-tested against local rail.

2. **Wired into Ymir:**
   - `snotra-transcribe.sh` Step 4b: reasoning pass after summarization
   - `snotra-trello.py`: classify() uses LLM first, keyword fallback; link_workstreams() uses LLM dedup
   - `trello_adapter.py`: resolve_member() uses LLM identity resolution
   - `snotra-card-moves.py`: generate_suggested_steps() uses LLM first, fallback to splitting
   - `meeting-outcomes.py`: --llm-extract flag (auto-enabled in pipeline)

3. **Template rendering engine** (`snotra-render-template.py`): Jinja2/simple substitution for email templates.

4. **Email template library** (`midgard/email-templates/`): 9 templates across 8 categories (client, internal, sales, board, standup, workshop, components).

5. **All Snotra files moved to systems/**: bin/time/snotra/ now contains only shims (Python shims for .py, shell shims for .sh). Actual code lives in systems/snotra/services/cron/ and systems/snotra/services/ear/.

## Why

The reasoning model (3rd AI model) improves extraction quality, suggested steps, duplicate detection, classification, and identity matching. The template rendering engine enables professional email generation. Moving all files to systems/ eliminates duplicates and follows the established shim pattern.

## Verification

All Python files pass py_compile. All shell scripts pass bash -n. Smoke test: extract (4 items), steps (5 steps), classify (patent), identity (Reygan Assareh), dedup (duplicate: ACT-001), test (ok). Pipeline with --llm-extract: 4 segments → 2 decisions + 3 actions, 11 documents rendered, no errors.
