## odrerir · unversioned · 2026-09-19 — a third view: Óðrerir joins the shell's window

### Why
- The shell knew two URLs (Hlidskjalf :3888, Smíðja :8437), so `--view odrerir` fell through to
  Hlidskjalf — the fourth rune had been routed to the shell by the gate but had nowhere to
  land. It now has a view of its own: `ODRERIR` (http://127.0.0.1:4322, where the hall is
  served), `IS_ODRERIR`, its own app name and slug (`ymir-odrerir`, matching its entry),
  a menu entry with ⌘/Ctrl+3, and the window-opening paths route to it.
- Three halls now open and switch in one window; every hall still runs standalone through
  `ymir <hall>`. The seat remains its own app until its renderer is given an address.

### Files
- `(see the body)`
