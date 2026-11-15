# Hand a brief to a worker — `eindri-send`

One command puts a line in front of a seated worker — on this machine, or on another machine's
pane — and it looks before it types. It refuses when the pane's input box already holds someone's
words, and it tells you whether the worker actually started.

## What it is

`bin/agents/eindri-send.sh` is the door the helm uses to talk to a worker. Every line it delivers is
stamped with who sent it, from which road and which machine, so a worker never has to guess whether
it is reading the Allfather, another agent or a script:

```
[from agent <name> (<harness>) · herdr pane <pane> · <machine>] <your words>
```

It does four things before it calls the send a success:

1. **reads the input box** of the target pane;
2. **refuses** when the box holds text — it never clears it, because those words may be the
   Allfather's;
3. **sends** with the right verb for that machine's herdr;
4. **waits, then asks**, and resends once only if nothing landed.

## What you need

- `herdr` on this machine, and a live agent standing in the target pane.
- For another machine: a road to it in the home's fleet registry (it carries the ssh user and the
  tailnet name) and your own ssh key seated there.
- The target: a pane id on this machine (`<workspace>:<pane>`, one colon), or
  `<machine>:<pane id>` for another machine.

## The commands

| Command | What it does |
|---|---|
| `bin/agents/eindri-send.sh <pane> "<text>"` | hands the line to the worker in that pane, here |
| `bin/agents/eindri-send.sh <machine>:<pane> "<text>"` | the same, over the fleet's roads |
| `bin/agents/eindri-send.sh --machine <name> <pane> "<text>"` | names the machine explicitly |
| `bin/agents/eindri-send.sh --from "<who>" <pane> "<text>"` | signs the line with your own name |
| `bin/agents/eindri-send.sh --wait 40 <pane> "<text>"` | waits longer before judging the landing |
| `bin/agents/eindri-send.sh --once <pane> "<text>"` | never resends |

The answer is one row:

```
eindri-send[1]{target,machine,pane,editor,road,sent,state,resent}:
  "<target>","<machine>","<pane>","empty","prompt","working","no"
```

`editor` is what the box held (`empty`, `text`, `unknown`), `road` is the verb the far herdr offered
(`prompt` on 0.9.x, `send` on 0.7.x), and `state` is what `herdr agent get` said afterwards.

`resent` says what the second look decided:

| `resent` | What happened |
|---|---|
| `no` | the worker went to work; nothing more was needed |
| `enter` | the words stood in the box unsent (a prompt delivered while the harness was starting), so Enter was pressed — never a second copy |
| `copy` | the line was lost, so it was sent once more |
| `none` | the box could not be read, so nothing was done; read the pane |

## Limits

- **It never clears a box.** A refused send is the door's whole point: clear or send those words in
  the pane itself, then call again.
- `unknown` in the `editor` column means the box could not be read (a harness drew it in a shape the
  reader does not know). The send proceeds and the door says so — read the pane afterwards.
- A retry happens only when the status is **not** `working` **and** the screen shows no activity. A
  spinner, `Working`, `queued` or `esc to interrupt` count as landed, even if `agent get` lags.
- Nothing is ever retyped into a box that already holds text: the door presses Enter instead.
- Text with control characters (Escape, Carriage Return) is refused: a brief is plain text.

## If it does not work

| What you see | What it means |
|---|---|
| `REFUSED — the input box of <pane> already holds someone's text` | exactly that; nothing was sent and nothing was cleared |
| `no agent stands in <pane>` | the pane is a bare terminal, not a worker |
| `no road to '<machine>'` | the fleet registry does not carry that machine; nothing was dialled |
| `cannot find a way to speak to a pane there` | the far herdr has neither `agent prompt` nor `agent send`; check what that machine runs |
| exit 5 | sent, but the worker never showed it was working — read the pane before sending again |

Fix notes: `docs/fixes/agents/2026-11-14-the-brief-looks-before-it-types.md`.

## CHANGE LOG

- 2026-11-14 — written with the change it describes (plan 293 part 5).
