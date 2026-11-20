## docs · 2026-10-21 — the front door names Snotra

### Why
The README described the crew and left out the one figure whose whole job is to hear. A meeting
assistant that is not named on the front door is a capability the operator has to remember
instead of read.

### Fix
A section, **Snotra — the ear at the table**, stating the three boundaries that make her safe to
run: the transcription is local (nothing leaves the machine), the agent-facing face is read-only
(an agent may read a meeting, never post into one), and a seat with no microphone reports a clean
skip rather than an empty transcript that reads like a quiet meeting. Plus the one line that
justifies her existence: *a meeting without minutes is a conversation, and the house does not
count conversations as work.*

### Verified
`docs-claims-guard` → every claim resolves across 124 pages.

### Files
- `README.md`
