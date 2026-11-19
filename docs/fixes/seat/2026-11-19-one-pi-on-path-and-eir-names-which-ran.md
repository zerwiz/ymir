# One pi on PATH, and Eir names which pi ran

**Date:** 2026-11-19 · **Component:** seat · **Doors:** `bin/seat/harness-extensions-install.sh` (the PATH block),
`bin/seat/pi-door.sh`, `bin/agents/eir-doctor.sh` (surface `pirun`), `config/surfaces.yaml` · **Tests:**
`bin/seat/tests/test_pi_door_path.sh`, `bin/seat/tests/test_pi_door.sh`

## What was wrong

`which -a pi` resolved mise's install first and the one-home door `~/.pi/agent/bin/pi` third. So `pi` typed in
`~/ymir` ran mise's binary, loaded both the checkout's and the pin's extension trees, printed 20+
`Tool X conflicts with ~/ymir/.pi/extensions/…` lines, and loaded nothing.

The PATH block the installer writes prepended the door once, when the rc ran. mise's activate hook rewrites `PATH` at
every prompt, after that block, and puts its own tool installs in front. The block was correct at startup and lost at
the first prompt.

Nothing could say which pi was actually running. `pidoor` asks what a shell would resolve, not what ran. On this
machine the pi holding the helm (pid 2243828) was mise's own install, started around the door.

## What was forged

- **The PATH block is v2.** It defines `_ymir_pi_door`, which moves the door to the front of `PATH` and drops its
  duplicates. The block runs it once and hangs it last on the prompt hook (bash `PROMPT_COMMAND`, zsh
  `precmd_functions`), so it runs after mise's hook at every prompt.
- **An older block is replaced, marker to marker.** The installer reads a block without the v2 mark as `stale`,
  keeps a backup (`<rc>.bak-ymir-pi-door`), and replaces only the lines between its own markers. The operator's lines
  are never touched. A second install changes nothing.
- **The door names its runs.** A pi the door starts carries `YMIR_PI_DOOR=<verdict>` in its environment. The last run
  is written to `<state>/ymir/pi-door.last`.
- **Eir's new `pirun` surface** lists every live pi with its pid and binary, and names each one that ran around the
  door. Its risk class is `never`: a running pi is restarted by its operator, never by a mend.
- The checkout's extension tree was not removed.

## Proof (measured)

The PATH block, in a fenced HOME with a mise-like prompt hook:

```
ok   the old block loses to the prompt hook (the measured fault)
ok   an older block reads stale
ok   the block is current after the seat
ok   one block, replaced in place
ok   the operator's own lines are untouched
ok   after the prompt hook, pi is the door
ok   the door sits on PATH exactly once
ok   a second seat changes nothing
10 passed, 0 failed
```

`pi` in `~/ymir`, listing models (no model was raised; the desk was held):

```
-- mise pi, bare:                                   44 "conflicts with" lines
-- through this branch's door (real pi = mise's):   0 "conflicts with" lines, rc=0, 495 lines of answer
pi-door: one home -> ~/ymir/.pi/extensions (60 pins)
at=2026-11-19T02:47:37Z pid=3743695 verdict=onehome tree=~/ymir/.pi/extensions bin=…/mise/installs/pi/latest/pi/pi cwd=~/ymir
```

Eir's `pirun` on this machine, before any release:

```
pid 2243828 ran ~/.local/share/mise/installs/pi/1.5.2/pi/pi around the door; pid 3683866 ran /usr/bin/node around the door — restart it from a shell whose pi is the door (~/.pi/agent/bin/pi)
```

> [!IMPORTANT]
> Owed after release: the installer must run once (an update does it) to replace the v1 block in `~/.profile` and
> `~/.bashrc` and copy the new door. Until then, every live pi reads "around the door", because the installed door
> predates the mark. A new shell, then `pi`, then `eir-doctor.sh` `pirun` is the field proof.

## CHANGE LOG

- **2026-11-19** — written with the change it describes.
