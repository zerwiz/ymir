# units.sh finds PyYAML where the installer put it

**Date:** 2026-11-16 · **Component:** engine / units · **Found while:** installing Ymir on a stock Mac

## What went wrong

`bin/engine/units.sh` ran `python3 -I units.py`. The `-I` flag isolates Python from the caller's directory and
environment, and it also hides the user site-packages. That is exactly where `prereq-ensure.sh pyyaml` installs
PyYAML (`pip install --user`).

A stock Mac has Python 3.9 and no system PyYAML. So every `units.sh` call failed with
`python3-yaml is required to read config/units.yaml`, even right after the installer said PyYAML was installed. The
service register could not be read, and no unit was written.

## What changed

`units.sh` picks its interpreter in this order:

1. `python3 -I`, when PyYAML imports under isolation (every Linux seat with `python3-yaml`);
2. the recorded engine interpreter (`~/.config/ymir/engram-python`) under `-I`;
3. `python3 -E`, which still ignores `PYTHON*` variables but keeps the user site;
4. `python3 -I` as before, so a machine with no parser still gets the named error.

Linux seats that had PyYAML keep the isolated road.

## How it was proved

On a Mac with only `/usr/bin/python3` (3.9) on the PATH and PyYAML in the user site, `units.sh list` printed the
register.

## CHANGE LOG

- 2026-11-15 — review-mend: added missing heading for #785
