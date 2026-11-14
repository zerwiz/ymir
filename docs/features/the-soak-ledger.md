# The soak ledger and the restart-storm ward

## What it is

Two halves of one thing: a machine that measures itself, and a machine that stops a fault
instead of letting it run all night.

**The ledger** writes one row per house service and per app every five minutes — memory, file
descriptors, inotify watches, child processes, GPU memory and restart counts. Those rows are
how a leak becomes a number you can read instead of a crash you have to explain.

**The ward** reads the restart counts and acts: a unit that restarts more than the limit inside
an hour is stopped, named, and its last error is sent to you through the house's message door.
That is the fault that took the heart down — two units restarted 2,277 times in two hours until
an 11 GB machine ran out of memory and swap.

Neither half restarts an app. Neither half stops anything while you are in a call, and the
sound and voice family is deferred rather than stopped.

## What you need

- Ymir installed, and the machine's own holder to enable the timer (one per machine, no root).
- `systemctl --user` for the units, and `nvidia-smi` for the GPU numbers on an NVIDIA card. A
  machine without it records `gpu_mib: null` rather than an invented zero.

## Do it

**See what is being measured, and whether the timer is up:**

```bash
bin/ward/soak-sampler.sh --status
```

**Take one pass by hand** (prints the rows and writes nothing):

```bash
bin/ward/soak-sampler.sh pass --dry-run
```

**Enable the five-minute timer on this machine:**

```bash
bin/ward/soak-sampler.sh --install-timer
```

It seats `ymir-soak.timer` → `ymir-soak.service`, running the sampler every five minutes from
the pinned runtime when the pin has this file, and from this tree otherwise. The unit says which
tree it runs from. Nothing is enabled on another machine: each machine's holder seats its own.

**Look at the ledger:**

```bash
ls "$(bin/vault/hodd.sh path | xargs dirname)/state/soak/services/"
tail -n 5 "$(bin/vault/hodd.sh path | xargs dirname)/state/soak/services/$(date +%F).jsonl"
```

**Run the storm ward by hand** (it reports what it would stop):

```bash
bin/ward/restart-storm.sh --pass --dry-run
bin/ward/restart-storm.sh --status
```

## The knobs

The values live in your home, never in the code: `$YMIR_HOME/config/soak.yaml`. Without that
file every value falls back to the default in the scripts, and `--status` prints both the value
and where it came from.

```yaml
restart_storm:
  enabled: true          # false = report only, stop nothing
  threshold: 10          # restarts inside the window, ABOVE WHICH a unit is stopped
  window_minutes: 60
  scope: user            # user | system | both
  exclude: ""            # extended regex of units never stopped
  defer_in_call: "^(snotra|speech-to-speech|kokoro|rodd|ymir-voice|pipewire|wireplumber)"
  cooldown_minutes: 60   # do not re-notify about one unit inside this window
sample:
  scope: user            # user | system | both
  include_vendor: false  # true samples the distribution's own units too
```

## What a row says

A service row names the unit, its state, its main pid, and the numbers for its whole cgroup (so a
worker process's memory counts toward the service that owns it). An app row names the app from
the app registry and counts its renderer processes with it.

```json
{"ts":"2026-11-14T03:38:22Z","kind":"service","name":"hlidskjalf-gate.service",
 "state":"active","restarts":0,"pids":1,"rss_kb":182344,"fds":47,"inotify_watches":3,
 "zombies":0,"gpu_mib":0}
```

Three extra row kinds: `pass` closes every pass with the counts, the seconds and the tree;
`discovery` says the app registry could not be read (so an empty app list is never mistaken for
a quiet machine); `storm` is the ward's own record of a unit it stopped.

## Limits, and what it will not do

- **It reads.** The sampler never touches a process. The ward stops a unit and nothing else.
- **Never the distribution's units.** A unit whose file is under `/usr/lib/systemd` is not the
  house's to stop; `sample.include_vendor` measures them, and nothing stops them.
- **Never during a call, if it is the sound.** While `bin/desk/in-call.sh holder` names a call,
  the units in `defer_in_call` are deferred and said so — the audio family is what the call is
  using.
- **A stop that fails is loud.** The row says `stop-failed` and the message goes CRITICAL. A ward
  without the privilege to stop a system unit says so rather than passing quietly.
- **The journal first, the ledger second, the counter third.** The ward says which source
  counted. A count nobody could take is not reported as zero.
- **An app's restart count is this machine's observation.** It moves when the app's main process
  changes between passes; a service's comes from systemd's own counter.

## If it does not work

- `soak-sampler.sh --status` says `inactive`: the timer is not seated here. Run
  `--install-timer` on this machine.
- No ledger file: the pass wrote nothing and said why on stderr (`exit 3`). Run
  `pass --dry-run` and read the fault.
- The ward stops nothing and `counter_only` is high: the journal could not be read for those
  units, so the count came from systemd's live counter. Check `journalctl --user -u <unit>`.
- A storm you want left alone: put the unit's name in `restart_storm.exclude` and re-run.

## CHANGE LOG

- **2026-11-14** — written with the feature (plan 286 P0 and P4, errand `leak-ledger`): the ledger's
  rows, the timer, the ward's limit and the knobs in `$YMIR_HOME/config/soak.yaml`.
