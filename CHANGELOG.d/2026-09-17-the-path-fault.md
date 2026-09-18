## 2026-09-17 — "ymir: command not found" is a PATH fault, and here is the cure

- **The command is installed; the shell is not looking.** The published manifest carries `bin: {ymir, ymir-install}`, so the file is there — in npm's global bin directory, which an ordinary Linux install puts under `~/.npm-global` and a shell profile often never adds.
- **The README answers it where a stuck user looks**: `npm prefix -g`, the `ls` that proves the command exists, the one-line `export PATH`, and the `EACCES` cure that sets a prefix the user owns instead of reaching for `sudo`.
