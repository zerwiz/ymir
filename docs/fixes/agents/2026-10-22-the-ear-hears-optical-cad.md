## agents · 2026-10-22 — the ear heard "OptiCAD", and now hears "Example4"

**His transcript:** he spoke *"Example4"* into Telegram and the assistant answered *"I don't have a fact
about OptiCAD"* — and on the next note, something about *"Example4 meowing like a cat"*. The loop worked;
the **ear** was the weak part.

```
measured[3]{condition,heard,why}:
  "as it was","'OptiCAD', 'Opti-Cat', 'Skernier'","a Telegram voice note is quiet (Opus, mono, often low level), and a general small.en model has never seen the word Example4"
  "with gain only","still shaky","level alone does not teach a name"
  "**gain + a vocabulary hint**","**'Skírnir, what is Example4? The inspection is on Friday.'**","the decoder is biased toward the words this house actually says"
```

**What changed in `ear.sh`:**
- the decode now normalises level — `volume=6dB,loudnorm=I=-16:TP=-1.5:LRA=11` — with a plain decode as
  fallback if the filter graph is unavailable;
- a **vocabulary hint** rides with the request: *Example4 · OVK · Skírnir · Snotra · Boverket · WayOf ·
  Whynot Productions · Example8 · ventilation inspection · Isabella · Craig · Brokk · Ymir*. Names only —
  it is a bias, never a private fact, and it is overridable with `WHISPER_VOCAB`.

**Verified on both shapes of note:** a Telegram-shaped OGG → *"Skírnir, what is Example4? The inspection is
on Friday."*; a Kokoro-generated note → *"Skírnir, what is Example4, and when is the OVK inspection?"*

**And one more thing learned from his paste:** the first two notes he sent hit the OLD process (the
restart came a minute later), which is why they were silent — a service that has just been changed must
be restarted before it can be judged.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a person the house meets. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
