---
section: surfaces-what-you-look-at
---
| Models | **The model chain** (`bin/bridge/bifrost-bridge.sh --chain` · `.agents/backend/model-bridge.py`) | One door carries the fallback for every hosted service: a hosted free model first, then the fleet's llama.cpp rails by their tailnet names, then a second hosted model. A step that is down, times out, rate-limits or refuses is passed over for 30 s, and every reply names the step that answered. The steps live in the home (`config/model-chain.json`); only llama.cpp is a local road | [docs/reference/ai-callers.md](docs/reference/ai-callers.md) |
