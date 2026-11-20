# hoard · unversioned · 2026-11-20 — the vault's writer read the stale plaintext, and its guard counted itself

`bin/vault/hodd-set.sh` wrote back a 75-key vault over a sealed copy holding 91. This note records what
was actually wrong (it was not the multi-line value), what now guards the door, and how each claim was
measured. Nothing here was repaired by hand-editing the vault.

## Why — the fault, measured

The door chose its **source** wrongly, and its **guard** could not see it.

1. **The source.** `hodd-set.sh` opened `platform.env` — the plaintext **sibling** — whenever that file was
   non-empty, and only decrypted `platform.env.age` when the plaintext was absent or empty. The writer has
   never refreshed the plaintext (that was the 2026-11-05 fault), so on this seat the sibling had been frozen
   since **2026-09-23 11:37**. Measured with the entry parser below:

   | file | entries |
   |---|---|
   | `hodd/secrets/platform.env.age` (the truth) | **93** |
   | `hodd/secrets/platform.env` (stale since Sep 23) | **74** |
   | `platform.env.age.bad-75keys-20261120T1631` (the writer's own output) | **75** = 74 + 1 |

   So the write was arithmetically perfect and factually ruinous: one key added to the stale copy, the
   result re-encrypted over the sealed one. **18 names** that the sealed copy held were gone from it. They
   are not printed here: a key name can name a person or a client, and this repository is public (RULES/04).

2. **The guard.** It said *"the decrypted plaintext must contain at least as many keys as the encrypted copy
   claims"* — and both numbers came from the same read of the same wrong file. A count compared against
   itself can never fail. It read `74 → 75` and passed.

3. **The reader.** `--list` printed the same wrong view, which is why it "missed" the `PLANE_*` names: they
   were in the vault, not in the stale plaintext.

4. **The parser.** Line-based `grep`/`awk` cannot edit a value that spans lines: it replaces only the first
   line of an entry, leaves the rest as orphan text, and counts any line inside a value that happens to look
   like `NAME=` as an entry. The vault holds armoured OpenSSH blocks, so this was a second, independent way
   to lose data in the same door.

## What the mend does

**`bin/vault/envfile.py` (new) — one parser, by whole entries.** An entry is a line, a quoted value that
spans lines, a backslash continuation, or an armoured block from its `BEGIN` to its own `END`. Everything
that is not an entry is carried through **byte for byte**: every record is a slice of the original text, so
a rewritten file is a concatenation of untouched slices, never a re-render. CLI: `names`, `count`, `has`,
`get`, `emit`, `set`, `del`, `diff`, `guard`.

A block whose `END` was lost stops at the next entry instead of scanning on to somebody else's `END`. This
is not hypothetical: the vault on this seat holds exactly one such entry, and the first version of this
parser swallowed the five live entries below it. The fixture that proves it is in the test.

**`bin/vault/hodd-set.sh` v2.0.0 — the sealed copy is the only source, and the guard is independent.**

1. When `.age` exists it is decrypted and used; the plaintext is not opened at all (a note says it is stale).
   The plaintext is read only for a file that has never been sealed, where it is the only thing there is.
2. The vault is decrypted a **second time from disk** and counted with the same parser. The write is refused
   unless the result is exactly *before + 1* (a new key), *before* (a replacement) or *before − 1* (a delete);
   a refusal names every entry that would go missing, **by name**.
3. The re-encrypted file is decrypted again and every entry except the touched one is compared with the
   vault on disk, byte for byte. Any difference refuses the write and the old file stays.
4. The backup, the atomic 0600 replace and the shredded temporaries are unchanged.

**`bin/vault/hodd.sh` v1.1.0 — one reader, and no silent fallback.** `emit`, `load` and the new `get` and
`names` read through the same parser, so a multi-line value arrives whole. `resolve_secret` now **refuses**
when a sealed copy exists but will not decrypt, instead of quietly serving the older plaintext: a reader that
cannot tell a stale copy from the vault reports the wrong truth as confidently as the right one.

**Three doors that read the plaintext directly.**

| door | was | now |
|---|---|---|
| `bin/bridge/a2a-mcp.sh` | read `platform.env` only, never `.age` | `bin/vault/hodd.sh get` |
| `bin/notify/mail.sh` | plaintext fallback whenever the door returned nothing | fallback only when no `.age` exists |
| `bin/mail/draft-age.sh` | same | same |

`bin/gates/guards/fixes-guard.sh` gained the row `bin/vault/* → hoard`, so a vault fix note can speak to a
vault change (before it, the record covered nothing and the gate said so).

## Proof

Every command below was run; the numbers are what it printed.

- **The old writer, reproduced** on a throwaway vault (sealed 91 entries + a stale plaintext of 5):
  it reported `"5 → 6"` and left the vault with **6** entries — 85 lost from one `set`.
- **The new writer, same fixture**: reported `"91 → 92"` and left the vault with **92**.
- **`bin/vault/tests/test_hodd_set_entries.sh`: 39 cases, all pass.** A throwaway age key and a temp home —
  the real vault is never opened, and no case prints a value. It covers: a 91-entry vault (89 plain keys, an
  OpenSSH block, a quoted two-line value); `--list` showing all 91 names and no value; set → 92 with every
  other entry byte-identical; replace → 92; delete → 91; a write that would drop entries refused **with the
  missing names**; a stale plaintext beside the `.age` never becoming the source; a sealed copy that will
  not decrypt refused (never replaced by the plaintext); an unterminated block that keeps its neighbours;
  and `hodd.sh` reading the same whole entries.
- **The real vault, read only** (`sha256` of `platform.env.age` identical before and after):
  `bin/vault/hodd.sh names secrets/platform.env | wc -l` → **93** (it was 74 names through the stale
  plaintext), both `PLANE_*` names present, and `get` of an armoured block → its whole **7 lines** instead
  of the first one.
- **Neighbouring suites, unchanged by the edit**: `bin/vault/tests/test_home_resolvers.sh` 11/11,
  `bin/mail/tests/test_draft_age.py` 16/16, `bin/mail/tests/test_gna.py` 49/49,
  `bin/bridge/tests/test_bifrost_provider.sh` 10/10, `bin/gates/tests/test_rules_compliance_env_file.sh` 3/3.

## Not done here, on purpose

- **The stale plaintext was not deleted.** It is the operator's file, and this errand was forbidden to touch
  the real vault. The door now ignores it and says so on stderr. `bin/vault/hodd-set.sh --list` shows what
  the sealed copy holds; once that is seen, `rm hodd/secrets/platform.env` retires the stale sibling.
- **The unterminated block in the real vault was not repaired.** `hodd-set.sh` now warns, naming it, and
  carries it through untouched. Repairing a secret by hand is the thing this door exists to prevent.
- `--get` now exits **1** when the key is absent (it used to exit 0 with empty output, so "absent" and
  "empty" could not be told apart). `bin/collab/publish.py` reports that case as *no `PLANE_API_TOKEN` in the
  vault*, which is the more accurate message.

## Files

- `bin/vault/envfile.py` (new) — the whole-entry parser and the write guard.
- `bin/vault/hodd-set.sh` — v2.0.0: sealed copy only, independent count, entry-by-entry round trip.
- `bin/vault/hodd.sh` — v1.1.0: `get` and `names`, shared parser, no stale-plaintext fallback.
- `bin/vault/tests/test_hodd_set_entries.sh` (new) — 39 cases on a throwaway key and temp home.
- `bin/bridge/a2a-mcp.sh`, `bin/notify/mail.sh`, `bin/mail/draft-age.sh` — the plaintext is never the source
  while a sealed copy exists.
- `bin/gates/guards/fixes-guard.sh` — `bin/vault/*` maps to the `hoard` component.
- `docs/features/the-vault-edit-door.md` and its catalogue row — the page teaches the guards that exist now.

## CHANGE LOG

- 2026-11-20 — the fix itself.
