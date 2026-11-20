---
section: memory-secrets
---
| Vault | **The vault locked to your GitHub SSH keys** (`bin/vault/vault-relock.sh`) | The secrets vault is encrypted to the owner's GitHub SSH keys instead of a key file kept beside it. `--plan` names who would be added or dropped and writes nothing; `--relock` decrypts with this seat's own key, re-encrypts to every declared key, decrypts the NEW file again and compares it **byte for byte** with the old plaintext before replacing anything, keeps a timestamped backup, and only ships with `--ship`; `--add-machine` prints the one `gh ssh-key add` command for this box and re-locks; `--check` answers four things and prints no value. The readers (`hodd.sh`, `hodd-set.sh`) decrypt with the seat's SSH identity and fall back to the old `age.key` only while it exists | [The vault locked to your GitHub SSH keys](docs/features/the-vault-locked-to-your-github-keys.md) |

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #848
