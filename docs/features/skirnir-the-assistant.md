# Skírnir — the Allfather's assistant

**What it is.** A separate, deliberately limited presence: it answers people when the Allfather is
away, takes a message, and says honestly when it does not know. It is **not** Brokk and cannot act as
him. The figure is Skírnir — Freyr's messenger, who goes in his lord's place, speaks his words, and
leaves the sword behind.

**What you need.** The vault (for state) and three approved fact files. Nothing else: he has no tools
to configure, because he has no tools.

**The commands**

```sh
bin/assistant/kb-export.sh                 # rebuild the digest from APPROVED facts only
bin/assistant/kb-export.sh --list          # what is approved right now
bin/assistant/ask.sh --tier collaborator --text "what is OptiCat?"
bin/assistant/ask.sh --tier collaborator --sender anna@example.com --text "nda please"
bin/assistant/voice.sh                     # talk to him: mic → whisper → Skírnir → Kokoro
bin/assistant/voice.sh --text "who are you" # the same, without a microphone
bin/assistant/walls-test.sh                # the red-team suite (10 assertions)
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

**What he may never do:** run a command, write a file, send mail, change a calendar or a board, read
the vault, the plans or the security posture, or speak as the Allfather. None of these is "disabled";
they are absent.

**If it does not work.** `walls-test.sh` first — it attacks him the way a hostile message would. If a
canary appears, the digest has a leak: fix the approved fact, not the filter.
