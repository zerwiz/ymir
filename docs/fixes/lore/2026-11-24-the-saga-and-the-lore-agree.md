# The saga and the lore agree — chapter XXXVII appended to docs/lore.md

## What was wrong

The Saga of Ymir (`docs/lorestory.md`) and the naming law (`docs/lore.md`) disagreed in three places, and the lore
page carried faults of its own:

- **The reforging.** Section VIII still names Rut-steel (Rust, NATS, gRPC, libgit2). The saga tells Rust for the core,
  Elixir with Ash for the fleet, and YmirCode first. Neither said what is built and what is only named.
- **The fleet count.** Section XXIII lists eleven rows (including Rödd, an app, and Nanna); section XXX says eight
  specialists and one primary; the saga names nine.
- **The saga's desktop face.** The saga says "a Tauri app"; YmirCode's built desktop app is native (egui).
- **Page faults.** A duplicated Smíðja's-eye block after section XXX, two chapters numbered XVII, a stray `\n`, a skill
  index that says 21 and lists 17, and sections that read as if the halls were public.

## What changed

Chapter XXXVII is appended to `docs/lore.md` (RULES/06 — nothing above it rewritten):

- the reforging as a table: Rust for the core and an Elixir/OTP plane for hosted work, both **decided** (YmirCode ADR 0012), the core **in design**, the plane **not started**;
- YmirCode recorded as it stands: specification and plans written, only a terminal UI prototype in code; the Tauri line corrected (ADR 0010: egui);
- the Einherjar defined as Brokk and the eight; every other card is a keeper or a craft;
- each page fault named with how to read past it;
- what the saga still owes (Chapter Three does not name the seven gates).

## Proved

Checked against the sources: `.agents/agents/` lists the cards named; YmirCode's `README.md` gives its status as design with only a terminal UI prototype in code; its ADR 0012 decides the Rust core and the separate Elixir/OTP plane; ADR 0010 decides the egui desktop.
