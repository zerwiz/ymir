# A worker talks back to its sender

## What went wrong

A dispatched worker was told to write a report file and a question file. Its sender learned of either only through a
wake about a file. The brief did not name the sender, and a bare `reply.sh` in a new worker had nobody to answer. A
dispatch from a script, or from a session with no pane, stamped a sender with no road back.

## What changed

- `bin/agents/sender.sh` records the sender of each errand at dispatch and writes the brief section that names it.
- `eindri-start.sh`, `herdr-run.sh eindri`, `einherjar-spawn.sh` and the engine call it. `--sender` carries a sender
  in from another machine. A review judge answers the sender of the judged errand.
- `eindri-acclaim.sh` sends each new terminal line to that sender.
- `reply.sh --errand` answers the recorded sender, and `reply.sh --ask` files a question and sends it in one act.
- A sender with no pane is answered through its machine's arm holder, also for `fleet-tell.sh` lines.

## Proof

`bin/agents/tests/test_sender_direct.sh`: a stand-in worker goes down each road, and its sender receives the question
and the result while both files are written. In this suite the panes, tmux, ssh and the other machine are fakes.

### Live run, one machine (2026-11-27)

A real dispatch on the engine road, from a real herdr pane, at head `e0947bf7d`. The sender's pane is `<sender>`, the
worker's pane `<worker>`. Machine, home and tree paths are replaced by placeholders, and the stamp's agent name by
`<agent>`.

```bash
bin/agents/eindri-start.sh "$(cat errand.md)" --id proof-971 --kind <harness> --effort low
```

```text
seat[1]{id,harness,model,backend,target,worktree,isolation,engine}:
  "proof-971", …, "herdr", "<worker>", "<worktree>", "off", "ymir_runtime/phase1"
sender=agent <agent> · herdr pane <sender> · <machine>
sender_road=pane
sender_address=<sender>
```

The errand told the worker to run these, in order, from the tree under test:

```bash
bin/agents/reply.sh --ask --errand proof-971 "proof-971 question: which word should my result carry?"
bin/agents/eindri-acclaim.sh proof-971 --terminal done --line "done: proof-971 result WORD" --evidence "test -f <tree>/bin/agents/sender.sh"
```

The sender answered between the two with `bin/agents/eindri-answer.sh proof-971 "rune"`.

`herdr agent read <sender> --source visible` showed both lines in the dispatching pane:

```text
❯ [reply from agent <agent> · herdr pane <worker> · <machine>] QUESTION from errand proof-971, waiting for your answer: proof-971 question: which word should my result carry? —
  answer with bin/agents/eindri-answer.sh proof-971 "<answer>" on <machine>
❯ [reply from agent <agent> · herdr pane <worker> · <machine>] errand proof-971 done: done: proof-971 result rune — full record:
  <state>/eindri-reports/proof-971.md
```

`herdr agent read <worker> --source visible`:

```text
● The question reached the sender: it was delivered to pane <sender> and filed at <state>/eindri-questions/proof-971.md.
  I am stopping here to wait for the answer word before I record the episode and send the result.
❯ [from the helm · herdr pane <sender> · <machine>] Answer to your question: rune
● Done: proof-971 result rune. The result reached pane <sender>, and the report is filed at
  state/eindri-reports/proof-971.md under Veil id <veil-id>.
```

What reached the operator, checked in the same run:

- No answer-back line: the voice room kept its 15 lines, none naming the errand, and no reply went to a terminal or a
  chat.
- Two desktop notes did fire, from roads this change does not touch: "Eindri proof-971 asks — answer it" when the
  question file appeared, and "Eindri proof-971 reported" from the terminal act.
- The report's receipt line also went to the arm holder's pane, which is an agent.

The errand record's mode was set to `scout` by hand after the dispatch, because the errand owed no pull request. The
terminal act read the worker's own state shelf, so the edit did not change the result.

### Second machine (2026-11-27)

**Question road: proven. Done road: proven by the last run, `proof-971-live`.** The first run, below, did not prove it.

A release of head `dfeb81923` was built on a second machine, its pin not flipped. The arm holder there dispatched
`proof-971-far` from that release with `--sender` naming a pane on the first machine.

The sender's pane read on the first machine:

```text
❯ [from agent <far-helm> · herdr pane <far-pane> · <far-machine>] [reply from agent <agent> · herdr pane <far-pane> · <far-machine>] QUESTION from errand proof-971-far, waiting for your
  answer: Proof question from <far-machine>: did this question reach you directly? — answer with bin/agents/eindri-answer.sh proof-971-far "<answer>" on <far-machine>
```

The sender answered with `bin/fleet/fleet-tell.sh --to <far-machine>:<far-pane> "<answer>"`. The first try reported no
answer within 25 s and the second reported a refusal, yet the worker had the answer.

The worker then said it had run `eindri-acclaim.sh proof-971-far --terminal done`, exit 0, with a Veil receipt id.
**No terminal line from that act reached the sender.** What did reach it were four near-identical chat replies of the
worker, relayed through the far arm holder. The worker's pane was closed by the seat reaper before it could be read,
so there is no worker-side read.

**Cause, reproduced here but not confirmed on that machine:** the act sent its message only when it was given
`--line`. The command the worker quoted has none, and an exit of 0 fits that: a done line with no evidence ends
`unproven`, not 0.

**Fixed after this run:** a terminal act with no `--line` now tells the sender once, and says nothing is proven. The
fix was then proven with fakes only. The two runs below took it across two machines.

#### The fallback run, `proof-971-far2` (head `aafa9bf8a`)

The second machine built a release of that head, its pin not flipped, and dispatched `proof-971-far2` from it with
`--sender 'agent claude · herdr pane <pane-A> · <machine-A>'`. The brief did not wait for an answer: `date -u`, then
`eindri-acclaim.sh proof-971-far2 --terminal done` with no line.

By then `<pane-A>` was gone, because the seat reaper had closed the finished seat. The message still went out. It came
back to the first machine's arm holder as an undelivered answer, wake `rodd-1795802037`:

```text
undelivered answer for pane <pane-A> (the pane did not take it …): [reply from agent claude · herdr pane <pane-B> ·
<machine-B>] errand proof-971-far2 said done with no line and no evidence weighed, so nothing is proven — record, if
any: …/proof-971-far2/eindri-reports/proof-971-far2.md
```

This text is copied from the pull request comment that recorded the run. It shows that a no-line terminal act reaches
across two machines, and that a line for a pane that is gone falls back to that machine's arm holder.

#### The live run, `proof-971-live` (head `aafa9bf8a`)

The first machine's pane `<pane-A>` was the sender and stayed open. A release of head `aafa9bf8a` on the second
machine dispatched `proof-971-live` with `--sender 'agent claude · herdr pane <pane-A> · <machine-A>'`. The second
machine's pin still pointed at another release. The brief did not wait for an answer and told the worker to run:

```bash
bin/agents/eindri-acclaim.sh proof-971-live --terminal done --line 'done: proof-971-live result rune' --evidence 'test -f bin/agents/sender.sh'
```

`herdr agent read <pane-A> --source visible` on the first machine showed the done line in the live pane:

```text
❯ [from agent <far-helm> · herdr pane <pane-B> · <machine-B>] [reply from agent <agent> · herdr pane <pane-B> · <machine-B>] errand proof-971-live done: done: proof-971-live result
  rune — full record: <seat-state>/eindri-reports/proof-971-live.md
```

The report named there, read on the second machine, shows the evidence command with exit 0, the commit `aafa9bf8a`
and the release tree as its repository. The errand's status there reads `done: done: proof-971-live result rune`.

Also open:

- A worker that asks and waits leaves its errand unfinished when nobody answers.
- The seat reaper can close a finished worker's pane before anyone reads it.
- A worker that is idle while it waits for a reply can be taken as finished without a terminal word. In the live run
  the sender kept its pane by appending `working:` status lines.
- An answer sent to a pane the send door could not verify was reported as not delivered although it arrived, and the
  worker saw it more than once.

## CHANGE LOG

- 2026-11-27 — a dispatched worker sends its result and questions to its sender.
- 2026-11-27 — appended: the live run on one machine; a brief keeps one sender stamp; a reply stamp never names the
  sender. The proof text that said no live pane was used is replaced by the run.
- 2026-11-27 — appended: the second-machine run: the question road proven, the done road not proven.
- 2026-11-27 — appended: two more two-machine runs. `proof-971-far2`: a no-line done for a pane that was gone came
  back to that machine's arm holder. `proof-971-live`: the done line landed in a live pane on the other machine. The
  second-machine summary that said "not proven" and "open gap" is replaced.
