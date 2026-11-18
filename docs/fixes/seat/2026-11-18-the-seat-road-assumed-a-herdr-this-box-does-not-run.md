## seat · 2026-11-18 — the seat road assumed a herdr this box does not run

### Why
`bin/seat/herdr-run.sh eindri …` is the one command that seats a worker. On the heart it refused
twice with "the pane must sit at an interactive shell prompt", and the agent had to be raised by
hand. The cause was a version assumption, measured: this box runs herdr 0.7.4, whose `agent start`
takes `-- <argv…>`, whose prompt verb is `agent send` (there is no `agent prompt`), and whose
`agent wait` takes `--status` (there is no `--until`). The script spoke 0.8.

Two more measured faults sat behind the first: `agent start --tab` seats the pane at the *tab's*
cwd, not the worktree's — a worker came up bare in `$HOME` — and the brief reached nobody.

The road now asks the CLI what verbs it has (`hdr agent`, once) instead of assuming a version, and
falls back to the road a hand uses: a single shell line in the pane, `cd`'d to the worktree, the
brief read from `state/eindri-briefs/<name>.md` so a quote in a brief can never become a shell
metacharacter. The seat is renamed, armed, and its form is printed (`0.8 --kind/--pane` or
`0.7 pane-run`) so the next hand can see which road answered.

### Files
- `bin/seat/herdr-run.sh`

### Proof
```
bin/seat/herdr-run.sh eindri seat-proof3 --kind pi --model opencode-go/deepseek-v4.1-flash --tab -- "Answer with one word: seated3"
# form "0.7 pane-run", interactive_ready "yes", injected "brief-in-launch", armed watch-seat-proof3
```

### CHANGE LOG
- 2026-11-18 — written with the fix, after the seat door refused on the heart.
