## install · unversioned · 2026-09-17 — the installer actually installs (the whole platform, then proves it)

### Why
- **Why pi.dev and opencode just work and Ymir did not.** They are one binary: JS only, no Electron, no build step, no services, no windows — and their `curl|sh` installer puts the command on PATH *and* runs onboarding. The npm path is the side door. Ymir is a platform: its install must place a CLI, four apps, their dependencies, four Electron runtimes (which npm gates), two SPA builds, desktop entries and icons, the services, and a home — eight things to go wrong, and npm fights half of them.
- **So the one-liner now finishes the job**, the way theirs does: it installs the command, then runs **the first setup**, then **proves what stands** and names the next door. `YMIR_SKIP_SETUP=1` installs the command alone, for anyone who wants the old behaviour.
- An installer that stops at a binary leaves the user with a tool that does nothing yet.

### Files
- *(carried from the frozen CHANGELOG.md)*
