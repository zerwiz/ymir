# The signal had no witness — why eleven browser deaths left no sender

**Date:** 2026-10-31 · **Component:** ward · **Status:** rules widened in the tree; the LIVE rules need one root command

## The fault in our own trap

`/etc/audit/rules.d/ymir.rules` watched the signal like this:

```
-a always,exit -F arch=b64 -S kill,tkill,tgkill -F a1=15 -k ymir-browserkill
-a always,exit -F arch=b64 -S kill,tkill,tgkill -F a1=9  -k ymir-browserkill
```

- **`tgkill` was filtered on the wrong argument.** Its signature is `tgkill(tgid, tid, sig)`: the signal is
  **`a2`**, and `a1` is the TID. `-F a1=9` therefore matched when a *thread id* was 9 — never. A
  thread-directed kill was invisible by construction.
- **`pidfd_send_signal` was not watched at all** — and that is precisely how systemd signals a unit's
  processes. Everything killed through a scope, a cgroup or that syscall left no record.
- **`rt_sigqueueinfo` / `rt_tgsigqueueinfo`** were not watched either.

That is why every browser death looked unsigned: SIGKILL at the wrapper (rc=137), no core, no OOM, no
audited kill. Eleven of them, the last three inside four minutes on 31 October (23:08:28, 23:09:24,
23:12:07 — the last one 71 seconds into a fresh start, 3.8 GB peak, window focused).

## The mend, in the tree

`bin/ward/garmr.sh` now emits one rule per arrival path, each filtered on the argument that actually
carries the signal:

```
-S kill              -F a1=15 / a1=9
-S tkill             -F a1=15 / a1=9
-S tgkill            -F a2=15 / a2=9        <- the fix
-S rt_sigqueueinfo   -F a1=15 / a1=9
-S rt_tgsigqueueinfo -F a2=15 / a2=9
-S pidfd_send_signal -F a1=15 / a1=9        <- the one systemd uses
```

A prepared file is at `/tmp/ymir.rules.new` (27 rules) for the live install.

## The one root command

```
sudo cp /tmp/ymir.rules.new /etc/audit/rules.d/ymir.rules && sudo augenrules --load && sudo auditctl -l | grep -c ymir-browserkill
```

Expect `12`. After that the next death names its hand: the finding carries `comm`, `pid`, `signal` and
`target_pid`, and the hound writes it to the kept shelf where evidence is never folded.

## Also fixed tonight, found while chasing this

The dedupe added to the hound hours earlier was folding **kill** findings into "1 repeat(s) folded"
rollup rows — losing `target_pid`, the one field that makes a kill evidence. Security rows are now
excluded from dedupe: volume may be counted, evidence may not.
