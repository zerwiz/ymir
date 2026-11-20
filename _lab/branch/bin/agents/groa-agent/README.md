# Gróa — the updater, one per install

**What this is:** Gróa — the updater shaman — given a body on every machine
that carries a Ymir install: `heimdall`, `omarchy`, `whynot`, `zerwizserver`.
One Gróa per install, because each install is its own tree and each seat is its
own machine; no Gróa reaches across.

**The naming.** Gróa is the völva who renews. `bin/agents/groa-update.sh` is her
hands — the fast-forward itself. This pack is her **body on a schedule**: a
leashed OpenCode agent that wakes daily and does what Gróa does, or reports why
she stopped.

## What she does, in order

```
run[5]{step,command,why}:
  "fetch","git fetch --all --prune","see what actually moved"
  "check","bin/agents/groa-update.sh --check","Gróa decides, not the agent"
  "update","bin/agents/groa-update.sh","fast-forward only"
  "migrations","bin/engine/ymir-migrate.sh status","a moved tree may need a moved home"
  "apps","bin/desktop/desktop-verify.sh","every desktop surface can actually open — runtime answers, launcher points at the live install, class routing agrees"
  "report","printed to the log","what was behind, what moved, what still needs a hand"
```

Gróa never commits, merges, rebases, pushes, branches, or edits a file by hand. If a
command fails it must stop and print the error, not improvise.

## Who Gróa is (her body must know this)

```
groa[6]{fact,value}:
  "file","bin/agents/groa-update.sh (alias: bin/agents/brokk-update.sh)"
  "what","the updater shaman: fast-forwards Brokk and every registered Eindri-home, then mends the tree forward"
  "never","forces, stashes, or creates a merge commit; skips anything dirty, diverged, offline, or on a non-default branch"
  "scope","only Brokk repos and their worktrees — never projects/"
  "prints","reread-Brokk: yes|no · galdr-reread: yes|no · nudge-eindri-homes: <id>…|none"
  "companions","bin/agents/eir-doctor.sh (the healer) · bin/engine/ymir-migrate.sh (the migrations) · bin/gates/checks/ymir-update-check.sh (npm drift)"
```

`--check` answers without changing anything. That is the mode the scheduled agent
uses first, and the only mode it uses if it cannot act safely.

## Her OpenCode pack, already in the repo

```
opencode_pack[3]{path,what}:
  ".opencode/agents/*.md","the agents as OpenCode subagents — brokk · groa · sindri · bragi · forseti · mimir · kvasir · huginn · muninn · snotra · tyr · galdr …"
  ".opencode/plugins/","the repo's OpenCode plugins"
  ".opencode/package.json","their dependencies"
```

Her body runs with a prompt as the contract, and `.opencode/agents/groa.md` is
the read-only definition of what she may be asked to do.

## The Ymir tools it may use

```
tools[6]{tool,use}:
  "bin/agents/groa-update.sh","the update itself, and --check"
  "bin/engine/ymir-migrate.sh","status | apply — the home's structure, versioned"
  "bin/gates/checks/ymir-update-check.sh","is a newer Ymir on npm? (exit 3 = yes)"
  "bin/agents/eir-doctor.sh","check | fix — every surface's health"
  "bin/fleet/agents-config.sh","the harness and model each agent should run on"
  "bin/agents/agent-run.sh","run one agent through its configured harness"
```

## Her model, and why this one

`opencode/nemotron-3-ultra-free` is free and answers headless in seconds. If it is
unavailable the runner falls back in this order:
`opencode/nemotron-3.5-lightning-free` → `opencode/glm-5.3-flash-free` →
`opencode/beam-free`. A free model is acceptable here **because the leash is
narrow**: five named commands, no writes, no history changes.

## Auth per host

OpenCode stores its credentials in `~/.local/share/opencode/auth.json` (0600).
Each host needs its own copy — copied once at install, never committed, never
pasted in a message.

## The leash

```
leash[4]{control,how}:
  "start/stop","groa-agent.sh start | stop | status"
  "timeout","YMIR_UPDATE_TIMEOUT (default 900s) — the agent cannot hang the machine"
  "log","$YMIR_HOME/hodd/state/groa-agent.log"
  "schedule","systemd --user timer, daily, staggered per host so installs never update at once"
```

## How she is seated (install and update)

```
bin/agents/groa-agent/seat.sh          # on that machine
```

It installs OpenCode if absent, writes the runner to `~/.local/bin/`, installs
`groa-agent.timer` (daily, with a per-host stagger minute), and runs one
`check` to prove the leash works. Idempotent: run it again after an update.
