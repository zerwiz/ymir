# Þing — the assembly hall (Galdr asset)

**Role:** Ymir's own meeting room — MiroTalk P2P, hosted on whynot, named **Þing**
(the assembly, the law-meeting; the plain where the free met was Þingvellir).
The name is **SEALED by the Allfather** (plan 53). The hall complements the ear:
Snotra (plan 52) records meetings held in other halls; Þing is a hall of our own,
so the ear can know the room, the participants, and the moment it began.

## The fork and its home

| | |
|---|---|
| upstream | `miroslavpejic85/mirotalk` (AGPLv3) |
| our fork | `zerwiz/mirotalk` — tracks upstream; branding/ops live here |
| code tree | the operator's fork checkout (e.g. `~/mirotalk`) |
| deployment | whynot — `~/thing/mirotalk`, port **3000**, unit `thing.service` (WantedBy `ymir.target`), public door `ping.zerwiz.org` via `cloudflared-thing` |
| plan of record | `.../whynotproductions/workspace/ymir/plans/53-thing-the-assembly.md` |

## How the brand works (the part everyone gets wrong)

The brand is **two** files, and the server one wins — but only after one trap:

```
app/src/config.template.js   the server brand — THE load-bearing file
                             materialized to app/src/config.js by npm prestart
public/js/brand.js           the client DEFAULT (fallback) brand
```

- The server serves `/brand` from `config.brand`; the client fetches it and
  deep-merges over its defaults (`mergeBrand`). Server values beat client.
- **The trap:** `brand.js` reads `window.sessionStorage['brandDataP2P']` FIRST.
  Once a browser has stored an old brand, it keeps serving that old brand —
  a hard refresh (cache clear) does **not** clear sessionStorage. After any
  rebrand, **bump the storage key** (e.g. `brandDataP2P` → `thingBrandData`)
  so every client forgets the old brand and fetches the new one.
- `config.html.*` flags (topSponsors, teams, poweredBy, sponsors,
  pastSponsors, advertisers, supportUs) toggle whole landing sections. Off =
  section hidden client-side; the bloat sections were also **deleted** from
  `public/views/landing.html` so the payload no longer carries them. The
  landmark `features` and `footer` sections stay on.
- The unit on whynot runs `node app/src/server.js` directly — **npm prestart
  never runs**, so `config.js` does NOT self-refresh on pull. After updating
  the template on the seat you must regenerate it by hand (below).

## Our look (the rebrand pass — landed 2026-09-24)

| what | where |
|---|---|
| name / titles / OG / join label | `config.template.js` brand block + `brand.js` defaults — `Þing`, `ENTER HALL`, `Ymir · Þing` |
| the mark | `public/images/logo.svg` = the Ymir Algiz-anvil (`assets/ymir-mark-algiz-anvil.svg`, same emblem Hlidskjalf's `Emblem.tsx` renders) — feeds favicon + every header/footer |
| the palette | stock MiroTalk blue (`--ds-brand-*: #4678f9`) → Ymir **slate + cyan + gold**: see `public/css/_tokens.css` (`--ds-brand-*`), `landing.css` body gradient, `client.css` `:root --body-bg` |
| about modal | `brand.about.*` — no author/email block; the hall's own words + `© Ymir — Þing` |
| footer | every view reduced to Privacy Policy + local `/api/v1/docs/` + `© 2026 Ymir — Þing` |
| lang | 16 `public/lang/*.json` — the rating prompt says Þing in every tongue |
| AGPL | upstream attribution kept literal (file headers, `mirotalk-*` css ids, license). A public fork honours the network-copyleft source offer by staying public. Never erase the licence. |

## Operations

### The deploy weld (after any fork change)

```
ssh whynot
cd ~/thing/mirotalk
git pull --ff-only origin master
cp app/src/config.template.js app/src/config.js     # the unit skips npm prestart
systemctl --user restart thing.service
```

### The cache lie

- `ping.zerwiz.org` is Cloudflare-backed (`cf-cache-status: DYNAMIC`), but
  **browser caches and sessionStorage** keep old pages alive:
  - sessionStorage brand → bump `brandDataKey` (above)
  - browser HTML cache → hard refresh (`Ctrl+Shift+R`) or a cache-busting query
  - edge → `bin/gjallarhorn-purge.sh ping.zerwiz.org` if a PoP held a copy
- Debug by driving a headless Chromium at the public URL and reading the
  rendered DOM (the wire usually serves the new page while a browser shows the
  old one — that asymmetry is the tell).

### Verification

- `node --check app/src/config.template.js public/js/brand.js public/js/client.js`
- The rendered landing must have ZERO `MiroTalk`/`sponsor` matches and the
  Þing title; `/brand` must return `message.app.name = "Þing"` with the bloat
  html flags false.
- No secrets, no names in the fork tree — public branding only (First Law).

## Not yet built (plan 53 phases)

P1 tailnet TLS · P2 coturn + the guests' door · P3 the OIDC gate (Heimdall) ·
P4 the ear inside the room (Snotra auto-notified; minutes to the hoard) ·
P5 the SFU only if mesh is outgrown. The rebrand and the room engine are done;
the engineering phases wait on the Allfather's word.