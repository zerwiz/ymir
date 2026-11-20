# Unlock the vault with your phone

## What it is

Ymir's vault — **Hnitbjörg** — is an encrypted container for your private documents.
By default you open it with a **passphrase**. This feature adds a second way: a key
that lives **on your phone**. You plug the phone in, unlock it with your fingerprint
or PIN, and Ymir reads the key and opens the vault. The key never sits on the
computer, so an agent running on the machine cannot open the vault without you and
your phone.

## What you need

- An **Android phone** that can do USB file transfer (the "File transfer / MTP" mode
  almost every Android phone has).
- A **USB cable**.
- The vault already created (see *Create the vault*, below).
- The phone-key backend on the computer. Ymir's installer and its healer (Eir)
  provide it: the package **`gvfs-mtp`** (Debian/Ubuntu: `gvfs-backends`). Check with:

  ```bash
  bin/vault/hnitbjorg.sh phone-status
  ```

## Do it

### 1. Create the vault (once)

If you have not yet:

```bash
bin/vault/hnitbjorg.sh init --size 2G
```

It asks you to set a **passphrase** — that is your recovery key; keep it.

### 2. Put a key on your phone

Plug the phone in by USB, **unlock it**, and on the phone choose **File transfer /
MTP** (not "Charging only"). Then:

```bash
bin/vault/hnitbjorg.sh phone-enroll
```

You will be asked for your **existing vault passphrase** (this authorises the new
key). When it finishes, a key file lives in the phone's `Download` folder
(`Download/hnitbjorg.key`) and the vault has one more way in.

### 3. Open the vault with the phone

With the phone plugged in and unlocked:

```bash
bin/vault/hnitbjorg.sh open
```

Ymir reads the key from the phone and opens the vault. **Without** the phone it
simply asks for your passphrase, exactly as before.

When you are done:

```bash
bin/vault/hnitbjorg.sh close
```

### 4. Check, or revoke

```bash
bin/vault/hnitbjorg.sh phone-status     # is a key enrolled? is the phone here?
bin/vault/hnitbjorg.sh phone-remove     # revoke: removes the key's slot and the phone copy
```

## Notes and limits

- **USB only.** MTP (the phone's file transfer) does not work over Bluetooth —
  Android does not implement it — so the phone must be plugged in. A wireless
  unlock would have to be over Wi‑Fi, which is a different feature.
- **The gate is your phone's lock.** The key can be copied off a phone that is
  rooted or compromised, so treat the phone as a key you carry. Your **passphrase
  still works** and is your fallback — never delete it.
- **A FIDO2 hardware key is stronger** (a physical touch an agent cannot perform).
  See the vault's own reference for that path.
- **Your phone number is not involved.** Nothing is sent anywhere; Ymir only reads a
  file off the phone over the cable.

## If it does not work

| What you see | What to do |
|---|---|
| `no phone found` | Plug the phone in, **unlock it**, and pick *File transfer / MTP*; then retry. |
| `could not write the key to the phone` | The phone's storage is not writable over MTP — make sure it is unlocked and set to file transfer; some phones need a folder open in their file manager first. |
| `phone-mtp missing` in `phone-status` | Install the backend: `sudo pacman -S gvfs-mtp` (Arch) or `sudo apt install gvfs-backends` (Debian/Ubuntu). |
| The vault does not open with the phone | Use your passphrase, then re-run `phone-enroll`. |
