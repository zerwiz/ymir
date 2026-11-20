## skills · unversioned · 2026-09-23 — the video road: Bragi and Huginn read a talk in one command

### Why
- **A marketing or research brief that ignores video is half-blind** — the
  launch talks, the teardowns, and the walkthroughs carry the signal, and the
  `bragi-marketing` skill named only Firecrawl (web) and browser-use (logged-in
  actions). Nothing read a video.
- **The harness road fails closed on a bare box.** The Pi harness's own YouTube
  mode needs `GEMINI_API_KEY` or a signed-in Chromium. On a plain machine it
  answers:

  > *"Could not extract YouTube video content. Sign into Google in a supported
  > Chromium browser for automatic access, or set GEMINI_API_KEY."*

- **`yt-dlp` needs neither** — no key, no account, no browser. Used live on
  2026-09-23 to read a talk when the harness could not: three calls gave the
  metadata, the description (chapters, links, the author's own thesis), and the
  auto-generated captions.

### Fix
- **`.agents/skills/bragi-marketing/SKILL.md`** — a new **§6, "Video sources —
  the transcript road (keyless)"**: the three verbs (`--print` for metadata,
  `--print "%(description)s"` for the description, `--write-auto-sub` for the
  transcript), the VTT-to-text filter, a TOON block naming the three steps, and
  the gotchas learned the hard way (429 throttling and how to report it
  honestly; `--write-auto-sub` when none is published; write to `/tmp`, never
  the tree; cite the video and timestamp, never "the transcript says").
- **`bin/yt-transcript.sh`** — the recipe as a script (law 7: a recurring task
  becomes a tool, not prose). One command reads all three; `--meta` skips the
  captions; **exit 3 means partial** (metadata read, captions refused), so a
  throttled run is reported, never faked.

### Verification
- `bash -n` clean.
- Run live against a talk: the metadata and description were read and written;
  the transcript call hit YouTube's **429** and the script reported it as
  partial (`exit 3`) instead of failing or inventing text — the honest-failure
  shape the scraping plan also requires.

### Files
- `.agents/skills/bragi-marketing/SKILL.md`
- `bin/yt-transcript.sh`
