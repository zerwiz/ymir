#!/usr/bin/env bash
# pi-model-agnostic — pi must not EXPECT any model. Local and online are peers.
#
# The law (Allfather, 2026-09-17): a seat that answers is used; a seat that does not
# must not stop pi from starting. pi was failing at launch because providers pointed at
# local ports with nothing behind them:
#   [llama-cpp] failed to reach http://localhost:8080/v1/models: fetch failed
# An unreachable local seat is a SKIP, not an error.
#
# This prunes unreachable LOCAL providers from pi's models config, keeping every seat
# that answers and every online provider untouched.
#
#   bin/pi-model-agnostic.sh            # report and prune
#   bin/pi-model-agnostic.sh --dry-run  # report only
set -euo pipefail

CFG="${PI_MODELS_JSON:-$HOME/.pi/agent/models.json}"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
[ -f "$CFG" ] || { printf 'error: no pi models config at %s\nhelp: set PI_MODELS_JSON\n' "$CFG" >&2; exit 1; }

CFG="$CFG" DRY="$DRY" python3 - <<'INNER'
import json, os, shutil, sys, time, urllib.request

cfg = os.environ["CFG"]
dry = os.environ.get("DRY") == "1"
d = json.load(open(cfg))
providers = d.get("providers", {})

def reachable(url):
    if not url:
        return False
    probe = url.rstrip("/")
    if not probe.endswith("/v1"):
        probe += "/v1"
    try:
        with urllib.request.urlopen(probe + "/models", timeout=3) as r:
            return r.status == 200
    except Exception:
        return False

kept, dropped = [], []
for name, prov in providers.items():
    base = str(prov.get("baseUrl", ""))
    local = ("127.0.0.1" in base) or ("localhost" in base) or ("0.0.0.0" in base)
    if local and not reachable(base):
        dropped.append((name, base))
    else:
        kept.append(name)

print("pi_models[%d]{provider,base,verdict}:" % (len(kept) + len(dropped)))
for n in kept:
    print('  "%s","%s","kept"' % (n, providers[n].get("baseUrl", "")))
for n, b in dropped:
    print('  "%s","%s","unreachable local seat - pruned"' % (n, b))

if dropped and not dry:
    shutil.copy2(cfg, cfg + ".bak-" + time.strftime("%Y%m%d%H%M%S"))
    d["providers"] = {k: v for k, v in providers.items() if k in kept}
    dm = d.get("defaultProvider")
    if dm and dm not in kept and kept:
        d["defaultProvider"] = kept[0]
        ids = (d["providers"][kept[0]].get("models") or [{}])
        if ids and ids[0].get("id"):
            d["defaultModel"] = ids[0]["id"]
        print("  default -> %s / %s" % (d.get("defaultProvider"), d.get("defaultModel")))
    json.dump(d, open(cfg, "w"), indent=2)
    print("pi_models: %d pruned, backup beside the config" % len(dropped))
elif dry:
    print("pi_models: dry run - nothing written")
INNER
