# The vault — Hnitbjörg

## What it is

**Hnitbjörg** is Ymir's encrypted document vault: a **LUKS2 container** for private
documents, **sealed by default**. While it is sealed, only ciphertext is on disk — no
agent, no human recovers anything without the key. Open it to work; **close it when
done**. Its content may be under NDA and **never leaves the vault** (Rule 15).

## What you need

- Ymir installed; `cryptsetup` present (the installer's `vault` step and Eir ensure it).

## Do it

```bash
bin/vault/hnitbjorg.sh init --size 2G   # create it (prompts for a passphrase — yours alone)
bin/vault/hnitbjorg.sh open             # open + mount (sudo; prompts for the passphrase)
bin/vault/hnitbjorg.sh close            # unmount + seal
bin/vault/hnitbjorg.sh status           # sealed/open, size, mount
bin/vault/hnitbjorg.sh backup --to PATH # copy the encrypted container
bin/vault/hnitbjorg.sh passwd           # change the passphrase
```

It lives at `$YMIR_HOME/vault/hnitbjorg.img` (git‑ignored), mounts at `~/Vault` (0700),
and rides the fleet sync as ciphertext.

Ways to open it, beyond the passphrase:

- **Your phone** — [unlock with the phone](unlock-the-vault-with-your-phone.md).
- **A FIDO2 key** — [hardware key unlock](fido2-unlock-the-vault.md).
- **For vault *work*** — a [confidential session](confidential-session.md): no route off the vault.

## Notes and limits

- **Sealed by default; never automounts.** The passphrase is never stored.
- **While OPEN, any process as you — agents included — can read it.** So: close it when
  done, and do vault work in a **confidential session**.
- **Nothing leaves (Rule 15).** Not to the repo, the home, memory, tickets, logs, or any
  model. `vault-guard` refuses a commit that copies it verbatim.
- **Back up the container** somewhere safe; losing it (or its passphrase) loses the data.

## If it does not work

| What you see | What to do |
|---|---|
| `no vault at …` | Create it: `bin/vault/hnitbjorg.sh init --size 2G`. |
| `could not open` | Wrong passphrase, or the wrong key — try the passphrase. |
| A commit is refused by `vault-guard` | A file copies vault content verbatim — keep it inside the vault (Rule 15). |
| The mount is busy on `close` | A file in it is open — close it, then `close` again. |
