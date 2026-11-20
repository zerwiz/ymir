# The vault's edit door — set one secret without touching the file

**What it is.** `bin/vault/hodd-set.sh` sets, replaces, deletes or reads a single key inside the
age-encrypted vault. It exists because a hand-edit nearly destroyed the vault, and on 2026-11-20 it took a
91-key vault to 75 in one write. Both faults are now guards in the code.

**What you need.** The vault (`$YMIR_HOME/hodd/secrets/`), its `age.key`, and `age`.

## The commands

```sh
bin/vault/hodd-set.sh KEY VALUE                  # set or replace one key (secrets/platform.env)
printf '%s' "$SECRET" | bin/vault/hodd-set.sh --stdin KEY   # the value never rides argv
bin/vault/hodd-set.sh --get KEY                  # print one value (a whole block if it is one)
bin/vault/hodd-set.sh --list                     # print the KEY NAMES only
bin/vault/hodd-set.sh --del KEY                  # revoke one key
bin/vault/hodd-set.sh KEY VALUE secrets/other.env
```

To set everything in your own shell instead: `eval "$(bin/vault/hodd.sh emit secrets/platform.env)"`.

## The sealed copy is the only source

`KEY.age` is decrypted, edited and written back. When it exists, a plaintext `KEY` beside it is **never
read** — it is a record that went stale in silence, and on 2026-11-20 reading it is exactly what lost 18
secrets. The door says so on stderr when it finds one, and carries on with the sealed copy.

If the sealed copy exists and will not decrypt, the door **refuses**. It does not fall back to the
plaintext, because a reader that cannot tell a stale copy from the vault reports the wrong truth as
confidently as the right one.

## The guards, and the day each was missing

| guard | what it refuses |
|---|---|
| **whole entries** | a value that spans lines is one entry — a quoted value, a backslash continuation, an armoured `BEGIN … END` block. Every entry that is not being edited is carried through byte for byte |
| **an independent count** | the sealed file is decrypted again **from disk** and counted; the write must leave exactly *before + 1* (new key), *before* (replacement) or *before − 1* (delete). A refusal names the entries that would go missing |
| **a round trip** | the re-encrypted file is decrypted again and every entry except the touched one is compared byte for byte with the vault. Any difference keeps the old file |
| **a backup** | the previous file stays beside it as `*.age.bak-<UTC stamp>` |
| **an atomic write** | temp file + `mv`, mode `0600`, every plaintext temporary shredded |

On **2026-10-21** a hand-edit decrypted to nothing, the append still ran, and the re-encrypted file replaced
90 secrets with 3; a backup taken seconds earlier restored it. On **2026-11-20** the door itself read a
stale plaintext and wrote 75 keys over a vault of 91 — the count it checked was its own. Both are in
`docs/fixes/hoard/`; the second is why the count now comes from a second read of the disk.

## Limits

- It edits one file at a time, and only keys in the `NAME=value` shape.
- It does not rotate keys, and it will not create a vault that does not exist. (`hodd.sh init` makes the
  layout.)
- An armoured block whose `END` line was lost is **carried through as it is** and named in a warning. The
  door will not repair it, and will not let it swallow the entries below it.
- `--get` exits **1** when the key is absent, so "absent" and "empty value" can be told apart.

## If it does not work

Run `--list` first. If it prints names, the decryption is healthy and the key you passed is the problem; if
it refuses, the vault will not open — read the message, it names the file and the reason. A refusal from a
guard names the guard and the entries at risk; it refused on purpose, and nothing was written.

## CHANGE LOG

- **2026-11-12** — the page gained a CHANGE LOG so it carries its history (RULES/06).
- **2026-11-20** — rewritten for the whole-entry parser, the independent count and the sealed-copy-only rule.
