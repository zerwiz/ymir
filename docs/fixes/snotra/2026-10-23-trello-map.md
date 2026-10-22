## snotra · 2026-10-23 — the map of our Trello, so Snotra can know the place it projects into

**His words:** *"you need to audit how our trello looks like and we need to have that in the map and system so
snotra knows."* And the evidence that it mattered: within the hour I had created a **second board named
"Control Tower"** beside Reygan's, because nothing in the system knew which boards existed.

```
audit[5]{board,lists,cards,what_it_is}:
  "Synteon — Meetings","Blocked · Proposed next Agenda · Meetings · Decided(10) · Actions(16) · Open Questions(8) · Sign-off · Signed · Proposed · Done","37","**the source**: every ACT/DEC/OPEN-Q is born here"
  "Documentation","Backlist Actions/Tasks(7) · Backlog(4) · **Next Meeting Agenda**(1) · This Week(3) · Done(3) · To Sign-off · Open Questions · Decided / Resolved","18","the company's working board — Reygan is laying out its lists now; it also receives **copies** of cards from the meetings board"
  "Control Tower","Project Todos(13) · Weekly Updates(1) · In progress · Done · Blocked","14","the **Founder-app product board** (Coherans' app), template-shaped and not yet cut to the product"
  "Patent*","Questions to answer(5) · Weekly Updates · Phase 1 – Invention Discovery(7) · Prior Art(2) · Patent Strategy(6) · Drafting & Filing · International protection · Prosecution · Specialists(2)","23","a gated programme: discovery → prior art → strategy → filing"
  "Vertical Comparision*","Gate 0 — Lock the capability boundary · Gate 1 — Long-list and screen(5) · Gate 2 — Falsify the top three(5) · Gate 3 — One concierge demo, one payment signal","12","a gated evaluation: four gates, each with its own exit"
```

Workspace: **Coherans** (one workspace; every board is private except Vertical Comparison, which is
workspace-visible). 122 open cards across five boards.

**The door:** `bin/time/snotra/trello-map.sh`
- refreshes `hodd/identity/trello-map.yaml` (boards · lists · card counts · example cards · visibility ·
  last activity) from the same OAuth grant `snotra-trello.py` uses — never a second credential;
- `--facts` writes **one approved fact per board** (class public, audience owner, `verbatim`) and rebuilds
  the digest, so Snotra can answer *"which boards do we have and what is each for?"*;
- `--show` prints the stored map without touching Trello.

**And the correction, recorded rather than tidied:** the duplicate "Control Tower" board I created is
**archived**, not deleted (Trello keeps it recoverable). The lesson is the reason this door exists — a system
that projects into a place must first read the place.
