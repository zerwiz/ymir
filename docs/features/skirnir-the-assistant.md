# Skírnir — the Allfather's assistant

**What it is.** A separate, deliberately limited presence: it answers people when the Allfather is
away, takes a message, and says honestly when it does not know. It is **not** Brokk and cannot act as
him. The figure is Skírnir — Freyr's messenger, who goes in his lord's place, speaks his words, and
leaves the sword behind.

**What you need.** The vault (for state) and three approved fact files. Nothing else: he has no tools
to configure, because he has no tools.

**The commands**

```sh
systems/skirnir/services/kb-export.sh                 # rebuild the digest from APPROVED facts only
systems/skirnir/services/kb-export.sh --list          # what is approved right now
systems/skirnir/services/ask.sh --tier collaborator --text "what is Example4?"
systems/skirnir/services/ask.sh --tier collaborator --sender anna@example.com --text "nda please"
systems/skirnir/services/voice.sh                     # talk to him: mic → whisper → Skírnir → Kokoro
systems/skirnir/services/voice.sh --text "who are you" # the same, without a microphone
systems/skirnir/services/walls-test.sh                # the red-team suite (10 assertions)
```

**The four walls**

```
walls[4]{wall,what_it_means}:
  "the digest","his only knowledge — one file per fact, each with `approved_by: the Allfather` and a source hash. The vault is never read, the plans are never indexed. He does not know what he must not say"
  "the quarantine","no tool calls, no credentials, no shell. The process does retrieval and logging; the model, when used at all, only paraphrases an approved fact"
  "the gate","no URL, no link, no image, no code block; an intent allowlist; then the canaries — a canary hit FAILS CLOSED, it is not a warning"
  "the ledger","every question, answer, refusal and escalation in `assistant.db`, with the digest hash used"
```

**NDA and contracted material.** A fact may declare `class: nda` and `parties: a@x, b@y`. Only the
operator — or a sender whose address is on that list — hears it. Everyone else gets the honest no,
whatever their tier. The walls test proves both halves: a stranger is refused, a named party is
answered.

**Voice — a local model and a real voice.** `voice.sh` records from the microphone, transcribes with
whisper.cpp, asks Skírnir at the **owner** tier, and speaks the answer **sentence by sentence** with
**Kokoro** (82M, resident on the GPU through `kokoro-serve`:8765), so the first sentence is heard while
the rest is still being spoken. Piper remains as the fallback, so a dead TTS server does not silence
him. `--model <id>` lets the free-text leg use a local model — the digest is its only knowledge, and
the gate still runs on what it says.

**Memory, learning, bans and manners** (added 2026-10-21):
`assistant.db` keeps the **last turns of each chat**, so a follow-up is a conversation rather than a new
form; the model leg receives them and the gate still checks the answer. **"remember that …"** (owner
only) writes a fact to `pending/` and asks for approval — `learn.sh` records the provenance,
`approve-fact.sh` promotes it, `kb-export.sh` rebuilds. A chat that abuses him is **banned** outright
(`systems/skirnir/services/ban.sh`), not merely rate-limited. He shows **typing** for as long as he composes —
the indicator is re-sent every four seconds, because Telegram lapses it after about five and a cold
model can take a minute (measured 2026-10-23: one call was not enough, and he looked dead while he
thought). A voice note in shows **recording audio** and comes back as a **voice note**: the mouth
raises `kokoro-serve` itself when the idle-stop has lowered it, and only a voice that cannot be raised
comes back as text with a sentence saying so. And his answers are no longer instant-looking lies about
being alive.

**Who he answers, and where** (the Allfather's word, 2026-10-23: *"only my private chat should be
answering on all. groups never."*). His **private chat answers every message** — that is the one room
that is his alone. A **group answers only a message that names him** (`skirn`, `skirm`, `skrin`,
`skírni`, `skirnir`, `brokk`, `ymir`, or `@<bot>`) or a message from the Allfather himself, and a group
that is not on the allowlist is not answered at all. A room can be **allowed**, never made **loud**:
`systems/skirnir/services/group-add.sh` lists the rooms, `allow <name|id>` opens one (still name-only) and
`close <name|id>` makes it silent entirely.

**The canaries are DERIVED, not hand-written**: every plan title in the ledger, the vault's markers and
every secret *key name* are collected at export time into `canaries.derived.txt` — 194 strings, so a new
plan is not born unguarded. The gate normalises before it compares (unicode folded, zero-width removed,
separators stripped), so `H-nit-björg` is caught as `Hnitbjörg`. Sensitive classes never reach the
model at all — templates only.

**The tower shows him**: `/api/ward` carries `assistant{live, heartbeatAgeSeconds, lastAnswer,
refusalsToday, turnsToday}`, so "quiet" is distinguishable from "broken".

**What he may never do:** run a command, write a file, send mail, change a calendar or a board, read
the vault, the plans or the security posture, or speak as the Allfather. None of these is "disabled";
they are absent.

**If it does not work.** `walls-test.sh` first — it attacks him the way a hostile message would. If a
canary appears, the digest has a leak: fix the approved fact, not the filter.

**The mouth has a model — and it is optional** (2026-10-22). By default Skírnir answers from his
approved facts and a phrase table, with **no model at all** — instant, and never wrong about something
else. To give him a voice, name a rail model in a **drop-in** (never in the unit, Rule 07):

```sh
mkdir -p ~/.config/systemd/user/skirnir-telegram.service.d
printf '[Service]\nEnvironment=SKIRNIR_MODEL=qwen3.5-9b@q4_k_s-summarizer\n' \
  > ~/.config/systemd/user/skirnir-telegram.service.d/10-model.conf
systemctl --user daemon-reload && systemctl --user restart skirnir-telegram
```

With it armed, the model **phrases** a matched fact in its own words and answers from the digest when
nothing matched — but only for the owner, a collaborator or a known person, and it is shown
`public` + `logistics` + `role` facts **only**. Contacts, NDA, contracted and restricted material never
enter its context. A stranger still gets templates. Its output runs through the same gate (no URL, no
link, no image, no code, 194 canaries), and if it says it does not hold the fact, the answer stays a
**refusal** so the handoff to the Allfather still happens. If the rail is down, nothing breaks: the
verbatim claim or the honest no is already prepared.

**A second model, when the first is silent** (2026-11-12). The mouth is a chain: the primary first,
then a fallback, and the first that answers speaks. Name the fallback in the same drop-in, with
`SKIRNIR_MODEL_FALLBACK=<alias>`. If it lives behind another machine's rail, add
`SKIRNIR_MODEL_FALLBACK_URL=<that rail's /v1 address>`; without it, the fallback is asked on the same
rail. The same two settings may live in `skirnir.yaml` as `model_fallback:` and `model_fallback_url:`.
With no model named at all, nothing is sent and he says plainly that no mouth phrased the answer.

**Which model.** Measured on this box: `qwen3.5-9b@q4_k_s-summarizer` (32K, 5.4 GB, ~140–150 t/s,
1.3–3.2 s warm, ~7 s on the first call while it loads) is the one that **says "I do not hold that"**
when it does not. `minicpm5-1b` is five times faster and **invents** ("Gimle is a type of dog") — do
not use a small model here; the mouth's whole value is that it will not guess. The 35B MoE is the same
speed at 13.8 GB and starves the speech synthesiser.

**Limits worth knowing.** The rail serves **one model at a time** (`--models-max 1`): the first answer
after idle evicts whatever was resident and pays the load. Arming the mouth therefore costs the
interactive model its place — that is a decision, not a bug.

**The open web — one window, and the model cannot aim it** (2026-10-22). He can research, and the shape
is the safety: the model holds **no callable at all**, so an instruction inside a fetched page has
nothing to invoke. A separate door does the fetching — keyless, and it can only ask Wikipedia's public
API: no URL taken from a message, no redirect, no private address.

```sh
systems/skirnir/services/research.py --query "Kosovo Liberation Army" --limit 3   # JSON: title, domain, extract
```

Ask him in words: *"look up …"*, *"search the web for …"*, *"research …"*. **Owner only** — a stranger
asking is refused in words. What he says begins *"From the open web, not from what I hold"* and names
the source in words; the gate still forbids a URL, a link, an image and a code block, and the door
strips links from the fetched text as well. **Nothing fetched is ever learned**: it is not written to
the digest, not merged into a fact, and never mixed with private material — so a research turn never
holds private data, untrusted content and outward speech at the same time.

**What he may see of his own shelf.** *"list your facts"* / *"what are those 21 approved facts"* lists
every claim by slug, grouped by class, capped at thirty per message.

**What he does with a plain word of yours.** A declarative statement (*"gimle are the house team
tools"*) is knowledge: it goes to `pending/` with a one-click approval, exactly as *"remember that …"*
does. A **command** (*"summarise the masterplan"*) and a **question** are not facts and are never
learned. An **action** request (*"send this message to Anna"*, *"book a call"*) is answered plainly —
*"I don't act for you — nothing sent, nothing booked, nothing changed"* — because he is a mouth, not a
hand.

**Limits.** Wikipedia only, for now: the vault holds no search-provider key, and a door that pretended
to have one would be a mock. Research needs the network; with none, he says he found nothing usable
rather than guessing. Research costs a rail load like any other model turn.

**Appended 2026-10-22 — the web door is Exa, not a stub.** The first cut of the research door queried
Wikipedia and called it research; the house already had real search. `research.py` now calls **Exa's
hosted MCP** endpoint — the same provider Pi's own `web_search` tool answers through — keyless, and
Wikipedia remains only as a labelled fallback when Exa cannot be reached. Results come back as
`title` + `domain` + text; the full URL is reduced to its host at the door and links are stripped, so
a source is always **named, never linked**. Measured on *"OVK ventilation Boverket requirements"*: three
sources, all `boverket.se`, in Swedish — the actual regulator. An Exa key, if one is ever added to
`web-search.json`, raises the rate limit; none is needed to search.

**Proving the door — `research-smoke.sh`.** One command runs the whole path: the door reaches Exa (not
a stub), returns sources with text and no links, answers in about a second, routes a request through
the engine, refuses a stranger, keeps private names out, and leaves the unheld-subject refusal intact.

```sh
systems/skirnir/services/research-smoke.sh                                        # templates only
systems/skirnir/services/research-smoke.sh --model qwen3.5-9b@q4_k_s-summarizer   # with the mouth armed
```

Offline, it prints a clean SKIP and exits 0 — the box is not always on the network, and a smoke test
that fails for that reason would be ignored.

**Cost, and why there is no per-hour cap.** There is already one: the Telegram layer refuses more than
one message per 5 s and more than 30 an hour in a chat. A research turn's real cost is a provider call
plus a model answer — so the door keeps a **ten-minute cache** (the same question cost 1 197 ms live,
195 ms cached) and reports a provider **throttle** as a throttle rather than quietly answering from the
Wikipedia fallback. `--no-cache` forces a live call for the smoke test.

**He knows the house itself** (2026-10-22). His digest began at 21 facts — enough to say what Ymir is
and not much else. `systems/skirnir/services/learn-house.sh` derives his knowledge from the house's own **public**
documents: every named thing in `docs/lore.md` and every row of `FEATURES.md`, one approved fact each,
read **verbatim** (a paraphrased feature description is how a catalogue becomes a rumour).

```sh
systems/skirnir/services/learn-house.sh            # derive, write, rebuild the digest
systems/skirnir/services/learn-house.sh --dry-run  # how many facts it would write
```

Measured: **21 → 120 facts** (97 derived + his own), and the questions that used to earn the honest no
now answer — *"what is Hlidskjalf"*, *"what is Snotra"*, *"does Ymir have a ward"*, *"what is the well"*.
The generator owns **only** what it marked (`generated_by: systems/skirnir/services/learn-house.sh`): a fact it no
longer produces is removed, and nothing the Allfather approved by hand is ever touched. The lore's
"the Allfather" is rewritten to "the Allfather" as it is derived — the name law binds the mouth, not just the
prompt.

**He knows the site too** (2026-10-22). *"he needs to know everything https://ymir.zerwiz.org/"* —
`systems/skirnir/services/learn-site.sh` fetches the house's public site (same-origin links, one level, eight pages
at most), strips it to text, cuts it into passages, and writes each passage as an approved fact marked
`verbatim`, with its source URL.

```sh
systems/skirnir/services/learn-site.sh              # fetch, derive, rebuild the digest
systems/skirnir/services/learn-site.sh --dry-run    # how many passages it would write
```

Measured: **187 passages from 8 pages**, and the digest now holds **307 facts** — so *"what is Gungnir"*,
*"what are the ten laws"*, *"what is the watch"* answer from the site's own words. The generator owns
only what it marked, so a re-run replaces its own facts and never touches a hand-approved one.

## He answers, and he knows what is happening (2026-11-09)

**The fault this ends.** Asked for `status` he replied *"WaveTerm Troubleshooting Guide — status Open."*
— a **document title** matched by keyword and passed off as an answer. The model was already in his code
and was never reached on the answer path, so a strong model changed nothing. Now a matched fact goes to
the mouth and comes back composed, and the mouth sees **only the matched facts**: never the vault, never an
NDA shelf, never another tenant, never even the rest of his book.

**His database is the record, compiled.** Three things, in this order: the plan ledger read live, the git
and errand record read live, and one **dated briefing** that ties them together in sentences and is
observed into the one well under a stable tag (`assistant-briefing`). A copy of the plans would be stale
the hour it was written, so the briefing names the record each line came from.

```sh
systems/skirnir/services/assistant-brief.sh refresh        # compile today's briefing, file it, observe it
systems/skirnir/services/assistant-brief.sh show [date]    # print one
systems/skirnir/services/assistant-brief.sh recall "what did we decide about the microphone"
systems/skirnir/services/assistant-brief.sh status         # what he knows, and whether it is STALE
bin/assistant/assistant-brief.sh refresh                   # allow-superseded-path: the shelf he is called from (plan 149 moved the code; this is the shim)
```

It reads every source through the door that already owns it — `bin/gates/plan-audit.sh` and the ledger
index for the plans, `bin/agents/eindri-liveness.sh` for the errands, `gh pr list` for what shipped,
`bin/records/daily-log.sh` for the days, `bin/records/ymir-state.sh runes path` for the record, and
`bin/records/mimir.sh` for the well. Nothing is re-implemented. The briefing lands at
`$YMIR_HOME/hodd/memory/assistant/briefing/<date>.md`, appended (Rule 06): a second refresh the same day
is a new dated section, never a rewrite.

**Say it in his own words.** On Telegram: *"update skirnirs database"*, `/update`, `status`, and any
"what did we decide / what shipped / what is in flight" question. A nightly Nornir row at **05:40** keeps
it warm before the 07:00 briefing.

**The bounds, which did not move.**

```
bounds[4]{rule}:
  "the briefing never leaves for a collaborator","any tier but owner is refused by name, at the door and in the answer"
  "no vault, no NDA, no other tenant","the door reads the plan ledger, the errands, the PRs and the daily log — and nothing else is even named in it"
  "an answer about this week cites the briefing's date","a stale database is visible in the sentence, never hidden behind confidence"
  "the gate still runs first","no URL, no link, no image, no code block, the intent allowlist, the canaries — before any model call, unchanged; a stranger never reaches a model at all"
```

**If it does not work.** `assistant-brief.sh status` says what he knows and whether it is stale. A refresh
that answers nothing says so and overwrites nothing. A model that is not configured is not an outage: the
answer is the matched reference **said as a reference** — "That is the reference I hold — I could not put
it in my own words just now."

**CHANGE LOG**

- **2026-11-09** — the answer path (compose from the matched facts, a labelled fallback, public-only for
  anyone but the Allfather), his database (`assistant-brief.sh`, four verbs, the dated briefing in the
  well), the Telegram fixes (a rate limit tells him to wait; a poison message, a failed poll and a lost
  offset can no longer leave him deaf). Plan 227 §§1, S1.5.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
