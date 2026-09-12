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

# bragi — marketing — research/crawl (Firecrawl), agentic browser (browser-use)

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
bin/valknut-load.sh --all      # rebind agents/skills after adding this skill
```
