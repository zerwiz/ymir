## web · unversioned · 2026-11-28 — a search result needs a host

### Why

A live SearXNG answered with result addresses that had a scheme and no host. `bin/web/search.sh` passed them on: an
agent cannot open them, and each cost about 250 characters of the capped output.

### What changed

`is_web()` now requires a host, so such a result is dropped before the limit is applied.

### Files

- `bin/web/web.py`
- `bin/web/tests/test_web.py`

### Test

`python3 bin/web/tests/test_web.py`

## CHANGE LOG

- **2026-11-28** — written with the change it describes.
