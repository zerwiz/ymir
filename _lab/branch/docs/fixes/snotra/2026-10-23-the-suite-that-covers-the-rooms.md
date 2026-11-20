## snotra · 2026-10-23 — the suite that covers the rooms, and the two bugs it found in an hour

**His word:** *"we need to have a full smoketest suite for skírnir — we cannot have breaks like this on every update."*

### The suite — 36 checks, 1 skip, 0 fail

Every check exists because something **broke this way**:

```
covered[9]{surface,checks,why_it_is_there}:
  "the engine and the walls","answers · carries an intent · an unheld subject is refused","the matcher lied twice"
  "the Ymir pitch","\"what is ymir\" · \"tell Regan about Ymir\" · \"explain what ymir is\" · \"introduce ymir to a client\"","one phrasing was not enough: the second shape fell through"
  "the rooms","an open room answers an unnamed hello · a named-only room stays quiet · the group door lists its rooms","a room ignored Reygan because addressed_only was global and invisible"
  "the group's members","three ways to ask who is in the room","\"can you see who are in this group\" earned the honest no"
  "the handoff","it carries the person's NAME","it said \"someone in telegram-group\""
  "the tier gate","a stranger cannot hear a contact · the owner can","a leak would be invisible"
  "the voice","it refuses LOUDLY when kokoro is down (exit 3) · it comes back after a restart · the idle-stop leaves it up under a fresh lease","the voice died silently five minutes after every start"
  "the ledger and the rule","a nightly snapshot exists · the retention rule scans","memory that dies with the disk"
  "the far-side ear","the whole chain, or a SKIP that names the one blocked link","a skip that says nothing is how \"untested\" becomes \"passes\""
```

### The two bugs it found while being written

```
found[2]{bug,what_it_looked_like,fix}:
  "`GROUPS` is a **bash built-in array**","`GROUPFILE=…` worked; `GROUPS=…` silently became `1000` (the user's unix group), so the door read a file called `1000` and reported every room as not allowed","renamed to `GROUPFILE`, with the reason written above the line"
  "a **dry run recorded a real ask**","`escalate.sh --dry-run` printed the message *and* wrote the ask, so every smoke run left two phantom questions waiting on the Allfather","the dry-run returns before the record; 18 test asks were closed"
```

**Also fixed:** an unaddressed group message now **logs its reason** instead of skipping in silence, and the asker's display name (Telegram first + last, when there is no username) rides with the handoff.

**Verified:** `bin/assistant/smoke.sh` → **36 pass · 1 skip · 0 fail**, and the one skip is the far-side ear, which names the exact blocked link (ufw and the docker bridge).
