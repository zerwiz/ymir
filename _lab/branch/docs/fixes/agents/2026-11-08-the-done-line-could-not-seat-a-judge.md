# agents · 2026-11-08 — the done line could not seat a judge

## What

Every errand that reached a done line was told **"NO judge is seated"**. The acclaim bridge seats the
review judge by calling `bin/agents/eindri-review-spawn.sh`, and that door decides first whether there is
a PR to judge. When there is none it gave its claim back and skipped:

```
[ -n "$PR_URL" ] || { release_claim; skip "no PR in state/$ID.status (a local-only tip never reviews)"; }
```

`release_claim` was **defined seventy lines below that call**. Bash cannot call a function it has not
reached yet, so the line printed

```
bin/agents/eindri-review-spawn.sh: line 179: release_claim: command not found
```

and the caller — which judges a spawn by its exit code — read the failure as *the spawn died*, not as
*the door decided not to seat a judge*. Measured on the atomic-runtime seat, 2026-11-08: its own done
line filed the report and then reported `review spawn FAILED (rc=1)`.

## The change

`release_claim` is defined **above its first use**, beside `skip()`, and it guards an unset
`REVIEW_SPAWNED` so a caller that never claimed anything cannot trip `set -u`. One function, moved; no
behaviour changed for the path that does seat a judge.

## Proved

```
$ YMIR_REVIEW_DRY=1 bin/agents/eindri-review-spawn.sh atomic-runtime
review-spawn[1]{task,review,pr,branch,head,marker,brief,report,spawn}:
  "atomic-runtime","atomic-runtime-review","https://github.com/zerwiz/ymir/pull/588",…,"…/einherjar-spawn.sh atomic-runtime-review … --harness pi --model opencode-go/deepseek-v4.1-flash --effort high"
```

No `command not found`, and the door reaches its spawn line instead of failing before it.
