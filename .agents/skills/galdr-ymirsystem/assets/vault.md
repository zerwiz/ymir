# Hnitbjörg — the encrypted document vault

Hnitbjörg is the mountain stronghold where Suttungr hid the mead of poetry: here,
a **LUKS2 container** that holds the operator's private documents, **sealed by
default** and opened on demand. The name is the vault, not a person.

```
bin/vault/hnitbjorg.sh          the door (init · open · close · status · backup · passwd · fido2-*)
bin/vault/hnitbjorg-ensure.sh   the surface (cryptsetup + vault dir); composed by Eir and the installer
```

## The law of the vault

```
vault_law[4]{name,rule}:
  "Sealed by default","it NEVER automounts; on boot it stays closed"
  "Passphrase never stored","not in the repo, the home, env, shell history, or an agent's output"
  "Close when done","while OPEN, any process as the operator — agents included — can read the mount; unmounting is the real protection"
  "sudo-gated","open/close go through sudo, so the door costs the sudo password as well as the passphrase"
```

The threat model, honestly:

```
threat_model[4]{state,agents_can_read,why}:
  "sealed (unmounted)","no","only LUKS ciphertext is on disk; the key is never written"
  "open, same user","YES","Brokk, Eindri, any shell as the operator can read the mount"
  "open, separate user","no","(not implemented) a dedicated uid the agents do not run as"
  "sealed + FIDO2","no","opening needs a physical touch an agent cannot perform"
```

## Paths (Rule 07 — never hardcoded)

| What | Default | Override |
|---|---|---|
| Vault dir | `<home>/vault` | `YMIR_VAULT_DIR` |
| Container | `<home>/vault/hnitbjorg.img` | — |
| Mount point | `~/Vault` | `YMIR_VAULT_MNT` |

`<home>` resolves through `bin/vault/hoard-lib.sh` (`ymir_home_root`), so a
packaged install and a clone agree. The container is **one file with an embedded
LUKS2 header** — `systemd-cryptenroll` has no detached-header support, so FIDO2
enrollment requires it.

## Commands

```bash
bin/vault/hnitbjorg.sh init --size 2G   # create the container; prompts for a passphrase
bin/vault/hnitbjorg.sh open             # sudo cryptsetup open + mount; prompts for the passphrase
bin/vault/hnitbjorg.sh close            # unmount + seal
bin/vault/hnitbjorg.sh status           # sealed/open, size, mount, usage (TOON)
bin/vault/hnitbjorg.sh backup --to PATH # copy the encrypted container (header included)
bin/vault/hnitbjorg.sh passwd           # change the passphrase (luksChangeKey)
bin/vault/hnitbjorg.sh fido2-enroll     # enroll a FIDO2 token (needs a key)
bin/vault/hnitbjorg.sh fido2-list       # list enrolled tokens
```

## Fleet reach

The container lives in the operator's **home**, which is the fleet's shared state.
Because the image is a large binary, it should NOT churn in git history: the home
carries the pointer, and the ciphertext rides **`bin/fleet/tailscale-sync.sh`**
(rsync over ssh, peer-allowlisted). To move the vault to another seat:

```bash
# on the machine that holds it
bin/fleet/tailscale-sync.sh push <peer>     # configured peers move the configured set
# or move just the container by hand:
rsync -avP <home>/vault/hnitbjorg.img <peer>:<home>/vault/hnitbjorg.img
```

Then `open` it on that seat with the same passphrase. Git-ignore the `.img` in the
home so it never lands in the private repo's history.

## FIDO2 (the strongest anti-agent control)

When a security key arrives, bind a slot that requires a physical touch:

```bash
bin/vault/hnitbjorg.sh fido2-enroll     # sudo systemd-cryptenroll --fido2-device=auto <img>
bin/vault/hnitbjorg.sh fido2-list
```

Recommend a **YubiKey 5C NFC**, **Nitrokey 3**, or **Token2/Tillitis**. A TPM-only
slot is *not* agent-resistant — it is machine-bound, so anything on the box could
unlock it; FIDO2-with-touch is.

## Install & update

- The installer (`bin/engine/ymir-install.sh`, `step_vault`) ensures `cryptsetup`
  and the vault directory, and reports whether a vault stands. It **never creates
  one** — `init` asks for a passphrase only the operator may type.
- **Eir** (`bin/agents/eir-doctor.sh`) composes the `vault` surface: a sealed
  vault is *healthy*, not a fault. Gróa carries it on every update.
- Platform layer (Rule 05): `cryptsetup` is installed per-OS; anything else
  reports a clean skip.

## Tests

`tests/` covers the contract: `--version`/help fast paths, `status` TOON shape,
and the sealed-by-default guarantee (init is never automatic).
