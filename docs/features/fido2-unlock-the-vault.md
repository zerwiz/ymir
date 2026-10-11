# FIDO2 — unlock the vault with a hardware key

## What it is

Besides a passphrase or your phone, the vault (**Hnitbjörg**) can be opened with a
**FIDO2 hardware key** — a small USB/NFC token (YubiKey, Nitrokey, Token2, SoloKeys).
Bound to a LUKS slot, opening needs the physical key, optionally a PIN and a **touch**.
It is the one control an agent **cannot** satisfy: an agent cannot press your key.

## What you need

- A FIDO2 security key (one that implements the **`hmac-secret`** extension — e.g. a
  YubiKey 5).
- The vault created, and `systemd`/`cryptsetup` with the fido2 token plugin (present on
  Arch).

## Do it

```bash
bin/vault/hnitbjorg.sh fido2-enroll   # prompts for your EXISTING vault passphrase, then touch
bin/vault/hnitbjorg.sh fido2-list     # see enrolled tokens
```

`fido2-enroll` runs `systemd-cryptenroll --fido2-device=auto` on the container: it asks
for the passphrase (to authorise the new slot), then for a touch. This **adds** a slot —
your passphrase stays as recovery. After that, `bin/vault/hnitbjorg.sh open` accepts the
key (touch) **or** the passphrase.

## Notes and limits

- **Enroll a second key.** A lost key must not mean a lost vault — repeat with a backup
  token.
- **Keep the passphrase slot** until two keys are enrolled.
- **The key must be present at open time**; with no key, you fall back to the passphrase.
- **This is the strongest unlock.** TPM‑only is machine‑bound (anything on the box could
  unlock it); FIDO2‑with‑touch is not.

## If it does not work

| What you see | What to do |
|---|---|
| `No FIDO2 devices found` | Plug the key in; if it still fails, it may not support `hmac-secret`. |
| Enrollment fails on a token | The token is not FIDO2/hmac‑secret capable — use a YubiKey 5-class key. |
| The key stops working | The slot was removed, or the token is a different one — re‑enroll. |
