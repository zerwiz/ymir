## install · unversioned · 2026-09-30 — Ymir ensures the Pi packages and stops installing the Pi binary

### Why
pi-ensure.sh reached outside its scope. install_pi() installed the Pi BINARY, preferred 'mise install pi@latest', contained no npm path at all while its own error string claimed 'need mise or npm', and opened with 'have pi && return 0' so on any seat that already had some pi it did nothing and reported success. That is how a stale mise pi reached every seat while the installer reported healthy. The boundary is now explicit: the Pi binary belongs to the operator, on the operator's channel - npm, mise, or anything else - and Ymir neither installs it nor edits the operator's npm config, shell rc, or PATH to steer it. Ymir's only stake is the three packages its own function depends on (pi-mcp-adapter, pi-web-access, pi-lmstudio), installed through 'pi install' into Pi's own extension prefix, which needs no npm configuration and no sudo. status reports the answering version and its resolved origin so a duplicate is visible, but judges nothing and changes nothing.

### Files
- `bin/pi-ensure.sh`