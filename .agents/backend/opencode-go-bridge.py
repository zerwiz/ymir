#!/usr/bin/env python3
"""opencode-go-bridge.py — backward-compatible entry point.

The bridge grew a provider choice, so the implementation now lives in
`model-bridge.py`. This shim keeps every existing reference to
`opencode-go-bridge.py` working by delegating with `--provider opencode-go`.

Prefer `model-bridge.py` (or `bin/bifrost-bridge.sh --provider NAME`) for new
work; the full provider list is opencode-go, lmstudio, openai-compatible.
"""
import os
import sys


def main() -> int:
    # Load model-bridge.py by path (its name is not a valid module identifier).
    import importlib.util
    here = os.path.dirname(os.path.abspath(__file__))
    spec = importlib.util.spec_from_file_location(
        "model_bridge", os.path.join(here, "model-bridge.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    # Force the legacy provider unless the caller already chose one.
    if "--provider" not in sys.argv:
        sys.argv += ["--provider", "opencode-go"]
    return mod.main()


if __name__ == "__main__":
    sys.exit(main())
