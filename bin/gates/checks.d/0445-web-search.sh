#!/usr/bin/env bash
# web-search — search and extract answer with capped, labelled data, refuse unconfigured and private reads; no network.
gate web-search "web search and extraction: capped highlights, cache, refusals, data label (mocked providers)" \
     python3 "$ROOT/bin/web/tests/test_web.py"
