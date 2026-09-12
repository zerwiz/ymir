# DEVELOPER_SETUP — macOS

- Homebrew: `/bin/bash -c "$(curl -fsSL ...install/HEAD/install.sh)"`
- Toolchain: `brew install git bash python3 node`
- SSH keys at `~/.ssh/`.
- Local loop via `.agents/skills/lifecycle/*`.

## Gotchas
- Run bash scripts with `bash`, not `zsh`.
- Localhost port from `.env` `APP_PORT`.