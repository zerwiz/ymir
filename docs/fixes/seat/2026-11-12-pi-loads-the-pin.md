# pi loads the pin, and the door wins on PATH

## What broke

On 2026-11-12 `pi`, started by hand in the working tree, refused all 44 Ymir extensions with
"Tool X conflicts with ~/ymir-runtime/.pi/extensions/…". Two causes were measured.

1. `~/.pi/agent/settings.json` `extensions[]` named the working tree. `config/runtime.env` writes
   `YMIR_RUNTIME_DIR="$HOME/ymir-runtime"` with a literal `$HOME`, and `bin/seat/valknut-load.sh`
   read it with a bare `sed`, so the pin path never existed and was ignored. A Gróa run from a
   working tree therefore bound that tree (RULES/51: a root agent loads the pin).
2. The one-home door `~/.pi/agent/bin/pi` was installed but never first on PATH
   (`which -a pi` named the npm and mise copies first).

## What changed

- `bin/seat/valknut-load.sh` and `bin/seat/harness-extensions-install.sh` resolve the pin through
  `arm_pin_dir` (`bin/pi/arm-pin-lib.sh`), which expands `$HOME`. The pin wins whichever checkout
  runs them; the working tree is used only when no pin exists. The opencode, claude, codex and
  cursor binders in the installer read from that same resolved root.
- The installer writes one marked block, `# >>> ymir pi door >>>`, to the shell profile and its
  interactive rc, putting `~/.pi/agent/bin` first on PATH. It is idempotent and never rewrites an
  operator line. `YMIR_PI_DOOR_PATH=print` prints the block and writes nothing.
- Eir has a new surface, `pidoor`. It fails when `command -v pi` is not the door and names the fix.
  A new login shell is needed before it can turn green.

## Proof

`bin/seat/tests/test_pi_loads_the_pin.sh` runs in a temp HOME: 10 passed, 0 failed.

## CHANGE LOG

- **2026-11-12** — written by its errand; change-log section added at the gather.
