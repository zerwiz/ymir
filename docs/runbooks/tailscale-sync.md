# Runbook — syncing pi data across your machines with Tailscale

Ymir can sync the operator's **pi data** (model catalogs, settings, trust, and
per-machine agent overlays) between their **own** machines over Tailscale. It is
peer-to-peer: no central server, no relay, and nothing is shared with another
operator or another tenant.

Tool: `bin/tailscale-sync.sh`. Config: `config/tailscale-sync.yaml` (private,
from the tracked `config/tailscale-sync.example.yaml`).

## 1. Prerequisites

- **Tailscale installed and up** on every machine:
  ```bash
  tailscale up
  tailscale status        # your machines should be listed
  ```
- Each machine's `tailscale` is on the same tailnet (same login).

## 2. Configure the peers

```bash
bin/tailscale-sync.sh init      # copies the .example to config/tailscale-sync.yaml
$EDITOR config/tailscale-sync.yaml
```

```yaml
machine: my-machine
peers:
  - host: my-other-machine        # MagicDNS name or tailnet IP
paths:
  - ~/.pi/agent/models.json
  - ~/.pi/agent/models-store.json
  - ~/.pi/agent/settings.json
  - ~/.pi/agent/trust.json
  # per-machine agent/model overlays:
  # - ~/Ymir/config/agents.<host>.yaml
include_auth: false               # auth.json holds credentials; opt in per tailnet
```

Check it: `bin/tailscale-sync.sh status`

## 3. Two transports — pick per your tailnet

### A. Taildrop (works with **no** SSH; the default safe road)

Tailscale file transfer is permitted even when SSH is not. The syncer bundles
every configured path into **one** tarball and sends it; the peer unpacks it.

```bash
# on the sending machine
YMIR_SYNC_VIA=taildrop bin/tailscale-sync.sh push my-other-machine

# on the receiving machine
YMIR_SYNC_VIA=taildrop bin/tailscale-sync.sh receive        # or: receive <dir>
```

`receive` runs `tailscale file get` into `~/Downloads`, unpacks any
`ymir-sync-*.tar.gz` into `$HOME` (paths are stored relative to `$HOME`), and
removes the archive. Push is one-way; make Taildrop the default with
`export YMIR_SYNC_VIA=taildrop`.

### B. rsync over SSH (two-way, needs SSH allowed)

```bash
bin/tailscale-sync.sh push my-other-machine   # local -> peer
bin/tailscale-sync.sh pull my-other-machine   # peer -> local
bin/tailscale-sync.sh --dry-run push          # show what would move
```

This uses `ssh` over Tailscale. If the peer runs **Tailscale SSH**, the tailnet
ACL must allow it — otherwise you get
`tailnet policy does not permit you to SSH as user "<you>"`.

**Fix (admin console → Access controls)** — merge this top-level block:
```json
"ssh": [
  { "action": "accept",
    "src": ["autogroup:member"],
    "dst": ["autogroup:self"],
    "users": ["autogroup:nonroot", "root"] }
]
```
and enable the server on the peer: `sudo tailscale up --ssh`.

Prefer plain OpenSSH instead? Then disable Tailscale SSH
(`sudo tailscale up --ssh=false`), ensure `sshd` + your key, and point the
syncer at it: `YMIR_SSH="ssh -i ~/.ssh/id_ed25519" bin/tailscale-sync.sh push …`.

## 4. Different configs on different machines

Each machine keeps its own model/harness combination in
`config/agents.<hostname>.yaml`, deep-merged over `config/agents.yaml`. Add those
overlay paths to `paths:` so they travel in the bundle, and every machine picks
up its own combination. See `config/agents.machine.example.yaml`.

## 5. Troubleshooting

- `tailnet policy does not permit you to SSH as user …` — the ACL, not Ymir.
  Use Taildrop (§3A), or add the `ssh` rule / plain OpenSSH (§3B).
- `open ~/….json: no such file or directory` — an older build didn't expand `~`;
  update the runtime (`bin/brokk-update.sh`) and retry.
- Nothing arrives — on the receiver, confirm `tailscale status` shows the sender
  online, then run `receive` and check `~/Downloads`.
- Never sync `auth.json` unless you trust **every** listed peer; Tailscale
  encrypts the wire, not the trust.
