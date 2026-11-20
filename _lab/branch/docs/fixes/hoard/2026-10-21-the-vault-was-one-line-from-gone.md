# The vault was one line from gone — and now a door guards the edit

**Component:** hoard · **Seat:** heimdall · **Date:** 2026-10-21

## What happened

Adding three keys for the phone bark, I decrypted
`hodd/secrets/platform.env.age` by hand, appended three lines, re-encrypted and replaced the file.

The decryption had produced **nothing** (the cause was never proven). The append still ran, the
re-encryption still succeeded, and the file that replaced the vault contained **three lines instead
of ninety**.

**What saved it:** a backup taken in the same command, seconds earlier. Restored, and the door
(`bin/vault/hodd.sh emit`) read **87 keys** again. Then `bin/vault/hodd-set.sh` set the three keys
properly: 87 → 88 → 89 → 90, each step verified.

## The lesson, which is the whole point

**The vault is never edited by hand — not once, not carefully, not with a backup.** A hand-edit has
no guard, and this one failed in the worst possible way: it *succeeded*.

## The door that now exists

`bin/vault/hodd-set.sh KEY VALUE [FILE]`, with four guards, each of which was missing that hour:

1. **the plaintext must be non-empty and hold at least one KEY=value line** — the exact case that
   failed; it now refuses instead of writing;
2. **the re-encrypted file is decrypted again and compared byte-for-byte** before it replaces
   anything — a round-trip that does not match writes nothing;
3. **the old file is kept** as a timestamped backup beside it;
4. **atomic write, mode 0600**, and every plaintext temp is shredded.

`--list` prints key NAMES only; `--get` prints one value. Neither prints the file.

## What was never at risk

Nothing left the machine: the vault, its backup and the temp files were all local, the failed
attempt lived for about ninety seconds, and the account of it is here — appended, not tidied away.
