---
section: memory-secrets
---
| Secrets | **Secret scanning** (`bin/gates/secret-scan.sh` · `.gitleaks.toml` · the CI job) | Two questions before a change leaves a machine: does a credential ship, and does a word of the operator's ship. gitleaks' shared rules answer the first from `.gitleaks.toml`; the second is answered by rules GENERATED at run time from the operator's private deny list (`$YMIR_HOME/hodd/identity/public-deny.txt`), so the public repository carries no word of his and a scan of the whole history finds any that slipped in. `config` · `status` · `tree` · `dir` · `staged` are the verbs; a finding names the rule, the file and the line, and never the word | [Secret scanning](docs/features/secret-scanning.md) |
