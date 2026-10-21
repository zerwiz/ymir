# Approvals — a click answers a question

**What it is.** A notification that asks something and can be answered with one gesture.
`bin/notify/send.sh --ask` records the question, sends it as a notification whose click action runs
`bin/notify/approve.sh <id>`, and that opens a **zenity** question: *Approve* or *Decline*. The
decision is written into the vault, carved into Runes, and printed back.

**Why it exists.** The Allfather said it plainly: *"I'm clicking the notifications in Omarchy but
nothing happens when I click them — how can I approve things?"* They were one-way. Omarchy's notifier
supports `--exec`, so a notification can now carry a command; the door passes it through.

**The commands**

```sh
bin/notify/send.sh --source assistant --severity MEDIUM --ask \
  --message "Skírnir is built — approve him to stay armed?"
bin/notify/approve.sh <id>          # what the click runs (zenity, foot as a fallback)
```

**Where the answer lives.** `$YMIR_HOME/hodd/state/notify/approvals/<id>.json` — the question, who
asked, when, and the decision with its timestamp. A Rune carries the same line.

**Limits.** One question per notification, two answers (approve / decline), and no silent default: a
dismissed notification changes nothing. A question nobody answers stays open and is visible in the
record.

**If it does not work.** `bin/notify/approve.sh <id>` by hand prints the question and asks for `y`/`n`
when zenity is missing.
