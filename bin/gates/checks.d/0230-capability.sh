#!/usr/bin/env bash
# capability — the capability register is current.
gate capability "the capability register is current"           bash "$ROOT/bin/gates/capabilities.sh" --check
