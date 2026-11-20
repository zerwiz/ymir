## gates · 2026-11-20 — the historical fix notes lose the machines and the people

The 04:10 sweep queued 229 findings. The audit behind it reported **217 of them in 123 files**, and
every one of the 217 sat in `docs/fixes/`: no code, no test, no template — the written record of older
changes, naming a machine of this fleet, the user name of this machine, or a person and a client of
the operator's. Not one was a false positive. **122 of the 123 notes are redacted here**; the one left
is named, with its reason, at the foot of this note.

### The question this closes

PR #816 fixed the 36 findings that were code and recorded the 24 that were false positives. It left
these 217 to the Allfather (plan 287 §3): redact an old note by a dated correction, or keep it as
history. Two sweeps later the queue still carried them, the ward refused nothing, and the twice-daily
job exited `1` every morning over the same 123 files — which is how a real finding is lost in noise.

The sweep's own brief settles it for this class: the repository is the runtime and the apps, and a
private record leaves it **by a commit** that says what moved and why. So the words go, the fix each
note records stays, and the original text stays where it can never be erased — in git history.

### What changed

| What was written | What it reads now |
|---|---|
| the heart's user name, and its paths | `heart-a`, and `$HOME` for `/home/<user>` |
| the dev machine, the second machine, the reviewer, the third | `dev-a`, `second-a`, `review-a`, `third-a` |
| a person, a client, a company, a mail domain | invented examples (`Ingrid Lindqvist`, `Berta`, `Casper`, `Nordan`, `nordan.example`) |

A surname or a chat handle that stood **beside** a listed first name was redacted in the same breath:
a first name is not protected by hiding the first name alone.

Each touched note carries **one appended dated correction**, so nothing is silently rewritten
(RULES/06): the note still records its fix, and it now says that a name above has become a role.
No line of a note was deleted, and no fact of any fix changed.

### The measurement

```
before   findings: 217 in 123 file(s)      allowed: 10      FAIL
after    findings: 0                       allowed: 11      CLEAN
```

The eleventh allowed finding is the one note left below: its `path:line` is recorded in the home's
allow file, with the reason, so it is still counted and printed — a decision on the record, not a mute.

`bin/gates/agnostic-audit.sh` over the whole tree, the same engine the ward and the heart's clock use.
The 123 files were 28 components of the record — `snotra` 20, `agents` 18, `runtime` 13, `forge` 8,
`install` 7, `gimle` 7, `collab` 6, `seat` 5, and the rest single notes.

### What deliberately did not change

- **The Heimdall subsystem keeps its name.** A word that is a figure of the lore is the house's craft;
  only the box that happened to bear it was replaced, and only on the lines where it was used as a
  machine. The ward reads it as a `host:` entry for exactly that reason.
- **No note was deleted, moved, or shortened.** The append-only law holds; a redaction is a
  correction, and the correction says so in the note itself.
- **The deny list stays in the home** and is never printed — the report names a file and a line.

> [!IMPORTANT]
> This is the Allfather's call, taken on his standing instruction because it had waited two days and
> was costing a daily alarm. If he would rather keep the original wording, one new note reverts it:
> git history holds the words either way, so nothing has been lost that a decision cannot restore.

### The one note left, and why

One note records a tool that has since **left this tree** for its own project (RULES/58), and its
filename carries that project's name. The NDA ward reads a touched file's own name as well as its
lines, so any change to that note — even the redaction of one machine name — refuses the push. The
house already decided that note stays as the record, so it was left whole and its one line is
recorded in the home's allow file with that reason. Taking the machine name out of it needs a
decision that is the Allfather's: allow that project's name in the NDA gate, or teach the ward not to
judge the filename of a note that already existed.

### Files

- `bin/gates/agnostic-audit.sh` — read, not changed: it was already right, and its findings were real.
- `docs/fixes/**` — 122 notes redacted, each carrying its dated correction.
- This note.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #835
