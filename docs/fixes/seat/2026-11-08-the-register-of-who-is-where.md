# The register of who is where

**2026-11-08 · component: seat · plan 219 §20**

## What was wrong

Twice in one day a line went out with no identity in front of it and none behind it. A status request was
sent to eight panes and one of them was this session, so the Allfather received a note addressed to
"everyone". And two keepers were seated, one of which stood in the wrong directory and one whose model
emitted malformed markup — neither could be named afterwards except by pane id.

The Allfather said it in one sentence: *"you need to know whos ansering and who youre sending to."*

## What was forged

`bin/seat/who.sh` — the register. It joins three sources and guesses nothing:

```
sources[3]{source,answers}:
  "herdr agent list","which panes host an agent, its name, its harness and its cwd"
  "the cwd","which project, and which ERRAND when the pane stands in <repo>/.yggdrasil/<id>"
  "the lock record + herdr pane process-info","which pane hosts the session that holds the lock"
```

```
who.sh                → panes[N]{pane,name,project,errand,kind,holds,state}
who.sh --names        → one resolvable target per line
who.sh <name>         → exactly one pane, refusing on none or on many
who.sh --me           → this seat's own pane, label and errand
```

Measured after naming the four agents that had identified themselves:

```
"w3:p1Z","","ymir","voice-593303","","lock-holder,me","?"
"w3:p0","gimle-door","ymir",...   "w3:pZ","kit-notifies-arm","ymir",...
"w3:pY","registry-210","ymir",...  "w3:p21","ct-tenancy","Inmost-ControlTower",...
```

## Verified

```
bin/seat/who.sh --me   → me[1]{pane,label,project,errand,holds}:
                          "w3:p1Z","w3:p1Z · ymir · errand:voice-593303 · lock-holder,me",...
bin/seat/who.sh voice-593303 → target[1]{name,pane,label}: "voice-593303","w3:p1X",...
```

## Honest limits

The register reads herdr's cwd for a pane, which is the pane's own directory and not whatever a shell
inside it has `cd`-ed to. An unnamed agent can only be addressed by its pane id — which is why the four
that identified themselves were renamed. And a pane that hosts no agent is invisible here by design: the
register answers for agents, not for terminals.

## CHANGE LOG

- **2026-11-08** — Opened with the door, the three joined sources, and the first named register.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a client of the house. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
