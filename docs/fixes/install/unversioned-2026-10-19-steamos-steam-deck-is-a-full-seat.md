## install · unversioned · 2026-10-19 — SteamOS / Steam Deck is a full seat

### Why
A Steam Deck was expected to be a partial seat — a game console that happens to run
Arch. It is not: the desk install (`--role dev --yes`) runs **whole** on SteamOS 3,
proven end to end on 2026-10-19 (Hlidskjalf, the smithy, the bridges, the well, the
sandbox). The README now says so, and names the SteamOS facts an operator meets, so
"works on the handheld" is a claim with the shapes behind it rather than a hope.

### What SteamOS actually changes (all found live, all reported rather than faked)
- **The pacman keyring** ships unpopulated — `pacman -S` refuses everything until
  `sudo pacman-key --populate archlinux holo`. (The installer needs no system
  packages; this is only the operator's own tooling — tailscale, age.)
- **User-local toolchains are the norm** — node via nvm, python via uv, bun, `gh` all
  live under the user's home. The **user units** must carry that PATH
  (`%h/.local/bin` plus the node bin dir), not just `/usr/bin`; without it the units
  exit `127` and the fleet probe reports a role-owed program down. A seat whose
  interpreter is user-local is not an edge case — it is how the deck ships.
- **Container DNS** — `resolv.conf` points at `127.0.0.53` (the systemd-resolved
  stub), which is unreachable inside a rootless image build, so the Utgard image
  build **hangs** with no output and no error. `dns_servers` in
  `~/.config/containers/containers.conf` settles it; the build then lands.
- **No `hostname` binary** — `hostname -s` is a missing command on SteamOS;
  `hostnamectl --static` is the spelling there.
- **No `whisper-cpp` in `extra`, no build toolchain by default** — the meeting ear
  (`snotra`) has no engine to find. The honest state is reported, not papered over:
  the ear stays off until an engine is built or an AUR path is chosen.
