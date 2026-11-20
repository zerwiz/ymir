## agents · 2026-10-22 — the ear heard "OptiCAD", and now hears "OptiCat"

**His transcript:** he spoke *"OptiCat"* into Telegram and the assistant answered *"I don't have a fact
about OptiCAD"* — and on the next note, something about *"OptiCat meowing like a cat"*. The loop worked;
the **ear** was the weak part.

```
measured[3]{condition,heard,why}:
  "as it was","'OptiCAD', 'Opti-Cat', 'Skernier'","a Telegram voice note is quiet (Opus, mono, often low level), and a general small.en model has never seen the word OptiCat"
  "with gain only","still shaky","level alone does not teach a name"
  "**gain + a vocabulary hint**","**'Skírnir, what is OptiCat? The inspection is on Friday.'**","the decoder is biased toward the words this house actually says"
```

**What changed in `ear.sh`:**
- the decode now normalises level — `volume=6dB,loudnorm=I=-16:TP=-1.5:LRA=11` — with a plain decode as
  fallback if the filter graph is unavailable;
- a **vocabulary hint** rides with the request: *OptiCat · OVK · Skírnir · Snotra · Boverket · WayOf ·
  Whynot Productions · Synteon · ventilation inspection · Isabella · Craig · Brokk · Ymir*. Names only —
  it is a bias, never a private fact, and it is overridable with `WHISPER_VOCAB`.

**Verified on both shapes of note:** a Telegram-shaped OGG → *"Skírnir, what is OptiCat? The inspection is
on Friday."*; a Kokoro-generated note → *"Skírnir, what is OptiCat, and when is the OVK inspection?"*

**And one more thing learned from his paste:** the first two notes he sent hit the OLD process (the
restart came a minute later), which is why they were silent — a service that has just been changed must
be restarted before it can be judged.
