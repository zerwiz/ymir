#!/usr/bin/env python3
# bin/time/snotra/channel_kb.py -> systems/snotra/services/cron/channel_kb.py — RETIRED SHIM (plan 129)
import os, sys
_new = os.path.join(os.path.dirname(__file__), "..", "..", "..", "systems/snotra/services/cron", "channel_kb.py")
_new = os.path.normpath(_new)
if not os.path.isfile(_new):
    print(f"snotra: the door moved to systems/snotra/services/cron/channel_kb.py and is not there", file=sys.stderr)
    sys.exit(127)
exec(open(_new).read())
