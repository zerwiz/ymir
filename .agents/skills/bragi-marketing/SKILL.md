---
name: bragi
description: "Bragi — the skald, the marketing craft. Web research and crawling with Firecrawl, agentic browser actions with browser-use, and the case for why we win: competitive advantage, positioning, a why-us page, a competitor teardown, and the evidence gate that refuses a claim with no measurement. Use when the task is marketing, growth, content, social, outreach, SEO, or competitive positioning. Keywords — marketing, seo, content, campaign, social, competitor, competitive advantage, positioning, why us, teardown, evidence, crawl, scrape, firecrawl, browser-use."
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
bin/seat/valknut-load.sh --all      # rebind agents/skills after adding this skill
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

**The tool is `bin/agents/yt-transcript.sh`** — one command, all three reads, and it
answers even when the captions are refused (plan 316):

```sh
bin/agents/yt-transcript.sh <url>                 # metadata + description + transcript
bin/agents/yt-transcript.sh <url> --meta          # metadata + description only
bin/agents/yt-transcript.sh <url> --out DIR       # where the transcript lands
bin/agents/yt-transcript.sh <url> --refresh       # ignore the cached transcript
bin/agents/yt-transcript.sh <url> --keep-audio    # keep the audio too (debugging; off by default)
```

It walks a **ladder** and reports every rung it tried: captions on the default
client, captions on alternate player clients with a 2/6/15 s backoff, the
`timedtext` endpoint directly, then the **audio through whisper.cpp** — GPU first,
CPU while the desk is in a call or a local model holds the rail. The audio lives
in one scratch dir that is deleted on every exit path (the Allfather's second law:
only the transcript survives), so `--keep-audio` is the only way to end up with a
file you can hear.

It exits **3** when no road answered, naming each one and its reason — never an
empty transcript and never a zero dressed as a success. A private, age-gated or
geo-blocked video is a refusal, also exit 3. A second read of the same video is a
cache hit (`"cache","hit"`) and makes no network call.

Transcripts land on `$YMIR_HOME/hodd/docs/research/transcripts/` as Markdown with
front matter — source, uploader, duration, **the road that answered**, the cost in
seconds, the whisper model, and a `sha256` of the text.

The raw verbs, if you need them by hand:

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

- **429 Too Many Requests.** YouTube throttles caption downloads; the tool retries
  and rotates player clients, then takes the audio road. By hand, retry after a pause —
  the metadata and description calls usually still answer, so take what you can and
  say what you could not get.
- **A title may carry a `|`** ("But what is a neural network? | Deep learning chapter 1").
  Never parse metadata with a pipe delimiter: read `--dump-single-json` instead. The tool
  learned this the hard way and now splits on NUL.
- **`--write-auto-sub`** gives the generator's captions when the uploader
  published none — good enough to quote a thesis, and it must be labelled as
  auto-generated when cited.
- **The transcript goes to the home, never the tree.** It is source material, not an
  artifact; the tree carries only what the campaign needs (Rule 04).
- **Impersonation warning is harmless** — yt-dlp notes it wanted an impersonation
  target; the download still succeeds.
- **Cite the video, not the transcript.** A claim carries the video URL and the
  timestamp, never "the transcript says".

**Where it lands:** the tool writes to `$YMIR_HOME/hodd/docs/research/transcripts/`
by default; a campaign's distilled reading of it goes to the marketing workspace
(`$YMIR_HOME/workspaces/marketing/`), beside the Firecrawl output — the same shelf the
daily scrape round fills (plan 49). The how-to for a person is
`docs/features/read-a-video.md`.

## 7. Competitive advantage — the teardown, the screen, and the evidence gate

Why we win is a **research** question before it is a copywriting one, and a claim about it
is a lie until it carries a measurement.

- **The asset:** `assets/competitive-advantage.md` — the VRIO screen, the competitive set
  taken from deals we lost rather than from listicles, the one-page teardown with every
  fact dated and the rival's words verbatim, the two files (internal with limits, client
  with evidence), and the cadence.
- **The method, in the kit:** `bin/collab/kit/docs/advantage.md` — installed into a
  standardised repository as `docs/advantage.md`.
- **The gate:** `bin/collab/kit/scripts/advantage-audit.sh` — refuses a page whose claim
  has no evidence, naming the line. `--strict --check` is the door a client-facing page
  must pass before it is sent.
- **The law:** a claim with an empty evidence line is deleted, never softened.

Load it when the task is positioning, a "why us", a competitor teardown, or the question
"what is our competitive advantage?".

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-17** — §6 now describes the door that always answers (plan 316): the ladder of roads, the audio-then-whisper rung, the deleted media, the cache, and the pipe-in-a-title trap. The transcript shelf moved from `/tmp` to the home's research shelf.
