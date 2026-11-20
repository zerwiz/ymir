## skills · 2026-09-28 · the hall gets a card, and the metadata a crawler can read

### Why

The Allfather: *"we need to add og picture and meta data for ping.
https://ping.zerwiz.org/"* — and the served page proved him right. The hall was
shared as a bare link:

- `og:image` was `../images/logo.svg` — a **relative** path (a crawler has not
  fetched the page and cannot resolve it) to an **SVG** (which no crawler
  renders);
- `og:url` was **empty**;
- no `og:image:*` set, no locale, no canonical;
- the icon `<link>`s were relative too, so they broke on every nested route
  (`/join/<room>`, `/login`, `/404`).

So every share of `ping.zerwiz.org` unfurled to nothing.

### The change (in the fork `zerwiz/mirotalk` — PR #14)

The hall's brand and its social card are the FORK's, so the code change lives
there; this note is the ymir side's record of it, and the asset below is updated
in the same pass.

- **the card**: `tools/og-card/thing-og.html` (1200×630, the house composition —
  mark left, wordmark right, mono details, one bronze rule) drawn in the hall's
  own cloth (stone and bronze, Cormorant / Newsreader / IBM Plex Mono) with the
  hall's own Algiz-anvil mark. `tools/og-card/render.sh` cuts it into
  `public/images/thing-og.png` and `.jpg`; **the rasters are build artifacts**,
  re-cut whenever the brand moves.
- **the metadata**: `brand.og` now carries an absolute image (the JPEG) and an
  absolute url plus alt/type/width/height/locale; `htmlInjector.js` passes them
  through with absolute fallbacks; every view declares the `og:image:*` set; the
  landing gains a canonical and a `twitter:image:alt`; the icon links and the
  client brand that re-applies them become root-absolute.
- **proved** by booting the fork and reading the served landing: absolute
  `og:image`/`og:url`, the full `og:image:*` set, the canonical, and
  `/images/thing-og.jpg` serving `200 image/jpeg`.

### Why the ymir side is in this note

The card is a picture of a page, so it must be re-cut whenever the brand moves —
and a card nobody can regenerate goes stale silently. The render road is
therefore recorded in the owning asset, not only in the fork: **the HTML is the
source of truth, the raster is a build artifact**.

### Found, not fixed (named so it is not lost)

`npm ci` fails on the fork — the lock is out of sync (`Missing:
@jitsi/rnnoise-wasm@0.2.1`, `@mediapipe/selfie_segmentation@0.1.1675465747`) and
`Dockerfile` line 19 runs `npm ci --omit=dev`, so a fresh docker build of the
fork is broken today. `npm install` works; the OG proof used it and the lock was
reverted, so the fork PR carries no dependency churn.

galdr-reread: `thing-assembly-hall.md` — the look table gains the social card,
the deploy weld gains the re-render step, a new *The social card* section carries
the render road and the metadata rules, the verification list gains the OG
checks, and the lock finding is recorded.

### Files

- `.agents/skills/galdr-ymirsystem/assets/thing-assembly-hall.md`
