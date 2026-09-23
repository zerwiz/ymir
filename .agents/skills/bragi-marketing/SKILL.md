---
name: bragi
description: >-
  Bragi — the skald. The marketing craft: web research and crawling with
  Firecrawl (firecrawl.dev) and agentic browser actions with browser-use
  (github.com/browser-use/browser-use) — for SEO, content, competitive intel,
  campaigns, and posting. Use when the task is marketing, growth, content,
  social, or outreach. Keywords — marketing, seo, content, campaign, social,
  competitor, crawl, scrape, firecrawl, browser-use.
argument-hint: "[research | seo | content | campaign | competitor | post]"
---

# bragi-marketing — marketing — research/crawl (Firecrawl), agentic browser (browser-use)

> **Norse name:** **Bragi** (the skald, poetry's god). The marketing craft.

Bragi is how Ymir does **marketing**. Two validated open-source engines do the
work; this skill is the Norse shell the **marketing Eindri** (Bragi) works
through. Marketing output — a post, a landing page, a campaign — is a **real
artifact** grounded in **real sources**, never invented.

## 1. The engines (open-source first)

- **Firecrawl** — [firecrawl.dev](https://www.firecrawl.dev/): scrape, crawl,
  search, and map the web into clean **markdown / structured data**. The research
  and SEO engine.
  ```sh
  pip install firecrawl-py
  # FIRECRAWL_API_KEY from .env.local (never inline)
  ```
  REST: `POST /scrape`, `/crawl`, `/search`, `/map` — or the SDK:
  ```python
  from firecrawl import FirecrawlApp
  app = FirecrawlApp(api_key=os.environ["FIRECRAWL_API_KEY"])
  doc = app.scrape_url("https://example.com", params={"formats": ["markdown"]})
  ```
- **browser-use** — [github.com/browser-use/browser-use](https://github.com/browser-use/browser-use):
  an LLM-driven **browser agent** that clicks, types, and reads pages. For
  logged-in actions: publishing, posting, filling forms, reading dashboards.
  ```sh
  pip install browser-use
  ```
  ```python
  from browser_use import Agent
  agent = Agent(task="Post the launch thread to X", llm=<model from Bifrost / Pi catalog>)
  await agent.run()
  ```
- **Scrapy** *(optional)* — [scrapy.org](https://www.scrapy.org/): a Python
  scraping framework for **large or custom crawls** where Firecrawl is not the
  right tool (many pages, structured pipelines, scheduling). `pip install scrapy`.
  ```sh
  scrapy startproject research && cd research && scrapy crawl sources -o out.jsonl
  ```

## 2. The craft (the loop)

```
marketing_loop[5]{step,what}:
  "research","Firecrawl crawl/search the sources — cite every URL"
  "position","the angle: audience, promise, channel, keywords"
  "draft","copy, landing page, or asset — real text, on brand (Hnoss for visuals)"
  "publish","browser-use drives the channel (X / Discord / site); Gjallarhorn relay"
  "measure","crawl results, track metrics, feed learnings to the well"
```

## 3. Rules

1. **Real sources, cited.** Every claim carries its URL (Firecrawl output).
   Never invent a statistic, competitor, or quote.
2. **OSS engines, BYOK.** `FIRECRAWL_API_KEY` and any model key come from
   `.env.local` — never inline in Markdown or commits.
3. **Real artifact.** A brief becomes a file (post, page, calendar), not a plan.
4. **On brand.** Visual assets come from **Hnoss** (OpenDesign) + the `DESIGN.md`.
5. **Domain.** The marketing Eindri is **Bragi**, domain `utgard` (creative) per
   Rule 01; it does not implement product code (that is Sindri).

## 4. Install into Ymir

```sh
pip install firecrawl-py browser-use
# The keyless video road (section 6) — one binary, no key, no account:
#   yt-dlp        (already on heimdall at /usr/bin/yt-dlp)
bin/valknut-load.sh --all      # rebind agents/skills after adding this skill
```

## 5. The sibling craft — translation (Bragi carries words across tongues)

A message that must cross a language border is **translation** work — the
skald's second hand. Load the **`bragi-translation`** skill and its detailed
`assets/programs.md` (the exact programs + commands): whisper.cpp on heimdall
for voice → text, the llama router's local seats for text → text, ffmpeg for
the format door, and the hoard's `hodd/docs/translation/` for the record.

- A campaign going multilingual starts by loading `bragi-translation`.
- The translated artifact is a file in the hoard's translation record, never
  invented inline.

## 6. Video sources — the transcript road (keyless)

A talk, a launch, a teardown — the signal is in the **video**, and a marketing
brief that ignores it is half-blind. Videos are read with **yt-dlp**, which
needs no key, no account, and no signed-in browser. This is the road to reach for
first; the Pi harness's own YouTube mode needs `GEMINI_API_KEY` or a
signed-in Chromium, so it fails closed on a bare box.

**The tool is `bin/yt-transcript.sh`** — one command, all three reads:

```sh
bin/yt-transcript.sh <url>                 # metadata + description + transcript
bin/yt-transcript.sh <url> --meta          # metadata + description only
bin/yt-transcript.sh <url> --out DIR       # where the transcript lands (default /tmp)
```

It exits **3** when the captions are refused but the metadata was read — partial
work, reported honestly, never faked. The raw verbs, if you need them by hand:

```sh
URL="https://youtu.be/<id>"

# 1. the metadata — title | uploader | duration | upload date
yt-dlp --skip-download --print "%(title)s|%(uploader)s|%(duration)s|%(upload_date)s" "$URL"

# 2. the DESCRIPTION — often the real payload: chapters, links, the thesis
yt-dlp --skip-download --print "%(description)s" "$URL"

# 3. the TRANSCRIPT — auto-generated when none is published
yt-dlp --skip-download --write-auto-sub --sub-lang en --sub-format vtt \
  -o "/tmp/%(id)s.%(ext)s" "$URL"

# 4. read it as text
sed -e '/^WEBVTT/d' -e '/^[0-9][0-9]:/d' -e '/^$/d' /tmp/<id>.en.vtt | \
  sed 's/<[^>]*>//g' | uniq
```

```
video_road[3]{step,verb,why}:
  "metadata","--print %(title)s|%(uploader)s|%(duration)s|%(upload_date)s","who said it, when, how long"
  "description","--print %(description)s","chapters, links, the author's own summary"
  "transcript","--write-auto-sub --sub-lang en --sub-format vtt","the words, auto-generated when none are published"
```

**Gotchas, learned the hard way:**

- **429 Too Many Requests.** YouTube throttles caption downloads; retry after a
  pause. The metadata and description calls usually still answer, so take what
  you can and say what you could not get.
- **`--write-auto-sub`** gives the generator's captions when the uploader
  published none — good enough to quote a thesis, and it must be labelled as
  auto-generated when cited.
- **Write to `/tmp`, not the tree.** A transcript is source material, not an
  artifact; the tree carries only what the campaign needs (Rule 04).
- **Impersonation warning is harmless** — yt-dlp notes it wanted an impersonation
  target; the download still succeeds.
- **Cite the video, not the transcript.** A claim carries the video URL and the
  timestamp, never "the transcript says".

**Where it lands:** the scraped/transcribed source goes to the marketing
workspace (`$YMIR_HOME/workspaces/marketing/`), beside the Firecrawl output —
the same shelf the daily scrape round fills (plan 49).
