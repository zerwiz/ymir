#!/usr/bin/env python3
# bin/time/snotra/snotra-render-template.py -> systems/snotra/services/cron/snotra-render-template.py — RETIRED SHIM
import os, sys
_new = os.path.join(os.path.dirname(__file__), "..", "..", "..", "systems", "snotra", "services", "cron", "snotra-render-template.py")
_new = os.path.normpath(_new)
if not os.path.isfile(_new):
    print(f"snotra: the door moved to systems/snotra/services/cron/snotra-render-template.py and is not there", file=sys.stderr)
    sys.exit(127)
exec(open(_new).read())
