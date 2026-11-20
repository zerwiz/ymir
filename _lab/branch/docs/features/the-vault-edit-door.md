# The vault's edit door — set one secret without touching the file

**What it is.** `bin/vault/hodd-set.sh` sets or reads a single key inside the age-encrypted vault.
It exists because a hand-edit nearly destroyed it.

**What you need.** The vault (`$YMIR_HOME/hodd/secrets/`), its `age.key`, and `age`.

**The commands**

```sh
bin/vault/hodd-set.sh KEY VALUE          # set or replace one key (secrets/platform.env)
bin/vault/hodd-set.sh --get KEY          # print one value
bin/vault/hodd-set.sh --list             # print the KEY NAMES only
bin/vault/hodd-set.sh KEY VALUE secrets/other.env
```

**Why it is safe, and the day it was not.** On 2026-10-21 a hand-edit decrypted to nothing, the
append still ran, and the re-encrypted file replaced **90 secrets with 3**. A backup taken seconds
earlier restored it. This door carries the four guards that were missing:

1. the decrypted plaintext must be **non-empty** and hold at least one `KEY=value` line — otherwise
   nothing is written at all;
2. the re-encrypted file is **decrypted again and compared byte-for-byte** before it replaces
   anything;
3. the old file is kept as a timestamped backup beside it;
4. the write is atomic, mode **0600**, and every plaintext temporary is shredded.

**Limits.** It edits one file at a time and the vault's own `hodd.sh emit` remains the only reader
the rest of the house uses. It does not rotate keys, and it will not create a vault that does not
exist.

**If it does not work.** `--list` first: if it prints names, the decryption is healthy and the key
you passed is the problem. If it refuses, the message names the guard that refused — read it; it
refused on purpose.
