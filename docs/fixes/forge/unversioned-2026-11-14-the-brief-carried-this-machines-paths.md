## forge · unversioned · 2026-11-14 — the errand briefs carried this machine's own paths

The twice-daily private sweep found four things in the public repository that belong in the home.
Two of them were in the forge's errand briefs: the text a smith is handed named the checkout and the
verdict file **of the machine that wrote the brief**, as a literal path.

- `bin/forge/repair-errand.md:9` — *"You are a SMITH (an Eindri) in /home/zerwizserver/ymir."*
- `bin/forge/repair-errand.md:13` — the verdict path, `/home/zerwizserver/Documents/ymirhome/…`

`bin/forge/conflict-errand.md:11` carried the same checkout path.

### Why it is a fault and not a shortcut

The repository is public and its history is permanent (RULES/04), and a path that names one machine,
its operator and its home layout is the machine's address (RULES/39). A brief is a **template** that
two doors already render at dispatch time — `review-verdict.sh` for a refusal, `review-watch.sh` for a
conflicting head — so the paths had no reason to be baked in: those doors know the checkout they run
in and the verdict file they just wrote.

### What changed

| file | change |
|---|---|
| `bin/forge/repair-errand.md` | the checkout and the verdict file are `@REPO@` and `@REVIEW@`; the header names the placeholders instead of printing them, so a rendered brief does not read as substituted nonsense |
| `bin/forge/conflict-errand.md` | the checkout is `@REPO@` |
| `bin/forge/review-verdict.sh` | substitutes `@REPO@` with the checkout it runs in and `@REVIEW@` with the verdict file it wrote |
| `bin/forge/review-watch.sh` | substitutes `@REPO@` with the checkout it runs in |

### Proof

Rendering the briefs the way the doors do, with the tokens filled, prints the same errand it printed
before — a smith in the real checkout, reading the real verdict — but the repository now carries no
home directory:

```
sed -e "s|@PR@|1|g" -e "s|@HEAD@|abc123|g" -e "s|@VERDICT@|REFUSE|g" \
    -e "s|@REPO@|$PWD|g" -e "s|@REVIEW@|$STATE/eindri-reports/pr-1-review.md|g" \
    bin/forge/repair-errand.md | sed -n '8,15p'
```

The private sweep's own `ADDRESS /home/zerwizserver/` rule now finds nothing in the tree but the
scanner's rule line itself, which the allowlist covers.

### Files

- `bin/forge/repair-errand.md`
- `bin/forge/conflict-errand.md`
- `bin/forge/review-verdict.sh`
- `bin/forge/review-watch.sh`

Found by `bin/time/nornir-job-private-scan.sh` (sweep 2026-11-14T03:51:38Z), fixed under the
private-scan errand. The home's record of what moved is
`hodd/docs/machines/zerwizserver/2026-11-14-the-machine-paths-left-the-public-repo.md`.
