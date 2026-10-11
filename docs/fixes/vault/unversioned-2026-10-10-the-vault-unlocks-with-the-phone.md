## vault · unversioned · 2026-10-10 — the vault can unlock with the phone (ticket ymir/27, #29)

### What

Hnitbjörg gains a **phone key** — an unlock factor held on the operator's phone:

- `bin/vault/hnitbjorg.sh phone-enroll` — makes a random keyfile, places it in the
  phone's storage (MTP over USB), and adds it as a LUKS slot. The key is **never
  kept on this machine**.
- `open` now tries the phone key first when one is enrolled and the phone is
  reachable; the phone must be **unlocked** (the phone's biometric lock is the
  validation). It falls back to the passphrase whenever the phone is absent, the
  file is gone, or the key is wrong.
- `phone-status` / `phone-remove` — report, and revoke (remove the LUKS slot and
  the phone copy).
- `bin/vault/phone-lib.sh` — the MTP accessor, with the `YMIR_PHONE_ROOT` test
  seam so the flow is provable without a phone.

**Transport is MTP over USB.** MTP-over-Bluetooth is in the spec but Android does
not implement it and no Linux MTP client supports it — so this is USB-only. MTP is
reached through GVfs (`gvfs-mtp`, already present); **no app on the phone**, so it is
license-clean (Apache-2.0). The per-unlock-fingerprint app (`android-luks`) is
GPL-3.0 and is therefore **not** vendored — see tickets ymir/28–30.

### Verified

- `tests/e2e/vault-phone-proof.sh` — **all pass** offline (via the test seam): the
  library round-trips a file; `phone-status` is honest; `phone-enroll` refuses with
  no vault and with no phone (naming the next step); no marker on refusal.
- `bash -n` clean; `hnitbjorg.sh --version` = 1.0.0.

### Files

- `bin/vault/phone-lib.sh` (new)
- `bin/vault/hnitbjorg.sh`
- `.agents/skills/galdr-ymirsystem/assets/vault.md`
- `tests/e2e/vault-phone-proof.sh` (new)

### Also (found by the delivery gate)

The push's `defaults-guard` refused the tree: three places **guessed the operator
home** with `"${YMIR_HOME:-$HOME/Documents/ymirhome}"` — `bin/vault/hnitbjorg.sh`,
`bin/vault/hnitbjorg-ensure.sh`, and the installer's `step_vault` in
`bin/engine/ymir-install.sh`. Rule 07 gives the ONE default to `bin/vault/hoard-lib.sh`
alone. All three now resolve through `ymir_home_root` and fail loudly if the resolver
is absent, instead of restating where the home lives. `defaults-guard check` is clean.
