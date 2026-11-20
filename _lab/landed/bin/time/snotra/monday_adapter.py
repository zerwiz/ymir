#!/usr/bin/env python3
# bin/time/snotra/monday_adapter.py -> systems/snotra/services/cron/monday_adapter.py — RETIRED SHIM (plan 129)
import os, sys
_new = os.path.join(os.path.dirname(__file__), "..", "..", "..", "systems/snotra/services/cron", "monday_adapter.py")
_new = os.path.normpath(_new)
if not os.path.isfile(_new):
    print(f"snotra: the door moved to systems/snotra/services/cron/monday_adapter.py and is not there", file=sys.stderr)
    sys.exit(127)
exec(open(_new).read())
