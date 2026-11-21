---
section: agents-work-collaboration
---
| Events | **The events store** (`bin/records/events-append.sh`, `events-tail.sh`, `events-search.sh`) | One writer for what happened on the house: validated rows (ts, source, kind, subject, severity, key, body), deduped by key, in day files under the home's `state/events/`; Nornir job failures and Garmr findings are the first two sources | [docs/features/the-events-store.md](docs/features/the-events-store.md) |

## CHANGE LOG

- 2026-11-21 — review-mend: added missing heading for #880
