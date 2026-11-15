# The agnostic audit — your public repository carries your craft, never your life

**What it is.** One door that reads every tracked file in your Ymir checkout and tells you
whether the repository has stopped being agnostic. `~/ymir` is a **public** repository: it is
cloned by other people, on their machines, with their own fleets. So it may carry the engine, the
apps, the tools, the gates, the templates and the documents that teach them — and it may not carry
**your** life (the people you meet, your clients, your companies, their mail domains, your NDAs)
or an assumption about **your** fleet (a machine name, a user name, your tailnet, a machine count).

The words it looks for are never in the repository. They are read at run time from your home,
`hodd/identity/public-deny.txt`, which is seeded at install from
`hodd/identity/public-deny.txt.example` and then belongs to you. Two families are judged: the words
on that list, and two generic shapes no fleet may publish — a concrete private network address, and
a real machine before `ts.net`.

**Who it is for.** Whoever pushes to the repository, and the operator's heart, which runs the same
census twice a day. It is also the answer to "what is in here that should not be" — the report is a
list of files and lines, not a verdict about your code.

**What you need.** Your home (any Ymir install has one) and, for the fullest answer, a list filling
`hodd/identity/public-deny.txt`. With no list the door still runs: it judges the generic shapes and
says out loud that it read no words, rather than reporting a clean scan it did not perform.

**The commands.**

```bash
bin/gates/agnostic-audit.sh                     # the census: every tracked file, right now
bin/gates/agnostic-audit.sh --ref origin/main   # the same, over a fetched ref (what the clock runs)
bin/gates/agnostic-audit.sh check FILE...       # the ward: only what a push ADDS
bin/gates/agnostic-audit.sh --list              # the classes, and how many entries were read
```

The last line of every run is one row a machine can read:

```
agnostic_audit[1]{scope,findings,files,entries,verdict}:
  "origin/main","468","279","19","FAIL"
```

Exit is `0` when the tree is clean and `1` when it is not, so a cron, a CI job or a push hook can
act on it without reading prose.

**How it judges, and why the kinds matter.** A word scan cannot tell a machine from a figure of the
lore: this house's own gate is named Heimdall, and a box may be named Heimdall too. So each entry in
your list carries a kind. `name:` is a person, a client or a company, judged anywhere in a line.
`host:` is a machine or a user name, judged **only where it is used as one** (after a mailbox `@`, a
URL's double slash, `/home/`, a `host=` setting, or `ssh `) — the same word in prose is your craft
and stays. `domain:` is a mail or client domain, judged on a domain boundary.

**What it never does.** It never prints a word from your list. A finding names the file, the line
and **which entry** matched, by its position in your list, so you can look it up and the report can
be pasted anywhere without publishing what it protects.

**What it deliberately lets through.** A network **range** written as a CIDR block, and the
documentation addresses (the `192.0.2.0/24` block) — a range documents a shape, it does not name a
place your machine stands. A placeholder tailnet host (`<host>.tailnet.ts.net`). And anything already on the base
revision when the ward runs: a push is refused for what it **adds**, never for history it did not
write — that is the census's job, not the gate's.

**On the clock — two clocks, two moments, one engine.** Twice a day the fleet's **heart** runs both:
`bin/time/nornir-job-agnostic-audit.sh` fetches `origin/main` fresh and judges **what was published**
(the moment before a leak leaves), and `bin/time/nornir-job-private-scan.sh` runs after, over the
**working tree**, and triages what it finds into a queue and one errand. Both call this engine, so a
word is defined once and judged at two moments; neither spells the shapes a second time. A clean run
says nothing on the desk. The rows live in **your** home's cron overlay (`config/cron.yaml`) gated
`@heart`; the shipped `.agents/config/cron.yaml.example` carries them commented out, for any operator
to uncomment in their own minute:

```
@heart 06:00 bin/time/nornir-job-agnostic-audit.sh
@heart 18:00 bin/time/nornir-job-agnostic-audit.sh
@heart 06:10 bin/time/nornir-job-private-scan.sh
@heart 18:10 bin/time/nornir-job-private-scan.sh
```

The sweep also looks for the two things no list can know — a mailbox and a phone number — and the
**secret** half stays with `bin/gates/guards/secret-guard.sh` in CI and `bin/gates/secret-scan.sh`,
which judge a credential by its shape and need no list at all.

**Limits.** It judges **tracked** text (and untracked files in the ward's scope), not the whole git
history — an old commit still carries what it carried; that is plan 287's phase P6. It is a word
matcher, so a name can be spelled around; it is a census, not a proof. Its list is only as current as
you keep it: a machine that joins your fleet is a line in `public-deny.txt`, in the same breath. And
it never fixes anything — moving a file, or writing a role instead of a machine name, is a hand's
work, guided by the report.

**If it does not work.**

- *"the operator's words: NONE READ"* — your home has no `hodd/identity/public-deny.txt`. The
  install seeds it; on an older home run `.agents/migrations/0023-the-deny-list.sh`, or copy
  `hodd/identity/public-deny.txt.example` and replace the invented entries.
- *The ward refuses a push* — run `bin/gates/agnostic-audit.sh check <the files it names>` to see
  which lines are new, and rewrite the line: an invented example, a role instead of a machine, or
  move the file into your home.
- *Everything looks like a finding* — your list is too broad. A three-letter entry fires inside
  ordinary words; a word that is also a subsystem of the lore belongs in `host:`, not `name:`.
- *The clock says nothing at all* — the sweep prints a `note` when it could not read something (no
  deny list, no ripgrep, a failed fetch) rather than reporting a clean it did not perform;
  `hodd/state/private-scan/scan.log` and `state/cron.log` in your home have the rows.

**The proof it ships with.** `bin/gates/tests/test_agnostic_audit.sh` builds a throwaway repository
and an invented list, and proves that a planted name fails the census, that the word is never
printed, that a machine name in prose passes while the same name after `ssh ` fails, that a
documentation address passes while a concrete one fails, and that the ward refuses only what is new.

## CHANGE LOG

- **2026-11-14** — written with the audit it describes (plan 287 §5–§6): the census, the ward, the
  kinds, the twice-daily clock and the canary. The first census at `origin/main`: 468 findings in 279
  files.
