Subject: One set of files in every project — can we work this way?

Hi {{name}},

A short question about how we hand work between us, and a proposal that needs your yes.

**The problem.** When one of us stops — for a day, a week, or for good — the other has to work out where
things stand by reading the code, the tickets and the boards. That works, but it is slow, and the reasoning
behind the last few decisions is usually the first thing lost.

**The proposal.** Every project we work in carries four small files, in the repository itself, so the state
of the work is written where the work lives:

1. a **contract** — one page saying what the project is for, how a change is made, and what must never be
   done. Anyone new reads one file and cannot invent a rule.
2. a **baton** — one living page that always holds the last five minutes of whoever worked on it: where the
   work is, what is done, what is next, what is blocked and on whom, how to check it, and the traps that cost
   the last person time. It is rewritten at every handoff, never accumulated.
3. a **history** — every past baton, kept and dated, never rewritten. If one turns out to be wrong, the
   correction is a new one that cites it.
4. a **check** — a small command that refuses a baton which is missing a section, is too old, or names a file
   that is not there. It runs as part of the build, so a stale record fails the work instead of quietly
   misleading the next person.

**What it is not.** It is not a new tool, and it does not replace anything we already use. Trello stays
Trello and Gimlé stays Gimlé — this is about the repository, where the code and the decisions live, and it
sits underneath both. Nothing moves, nothing is migrated, and nobody has to sign in anywhere new.

**What it costs.** Nothing but a habit: before you stop, write half a page. The check does the rest, and it
will tell you what is missing rather than making you guess.

**What we ask.** May we use these four files in every project we share — {{projects}} — including the
repositories you touch? If you would rather have it in some projects and not others, say which, and we will
follow that.

We already use it on our side: it is running in the two projects where work passes between hands most often,
and it has already caught a record that had gone out of date. The two attached files are the shape of it — the
one-page law and the page you fill in — so you can see exactly what writing a baton looks like before you
answer.

**How to answer.** A single line is enough:

- *"Yes, all projects"* — and we start with the next handoff, nothing else needed from you.
- *"Yes, but only these"* — name them, and we will follow that.
- *"No"* — tell us what you would prefer, and we will write that down instead.

If you would like a ten-minute walk through it first, say so and we will set one up.

— {{from_name}}
