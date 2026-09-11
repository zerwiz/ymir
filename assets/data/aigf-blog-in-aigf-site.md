# Dirrty Mixbag Blog on AIGeeks & Freaks

**Status:** Planning  
**Last updated:** 2025-10-01  
**Projects:** AIGeeks & Freaks (`/home/zerwiz/CodeP/aigeeks&freeks`)

---

## 1. Goal

Add a blog section to the AIGeeks & Freaks homepage where AI-generated and community-written blog posts about agent engineering, MCP development, and swarm orchestration are published. The blog is separate from but linked to the Dirrty Mixbag community forum — it lives on the AIGF site and serves as the primary content hub for the AIGF audience.

---

## 2. Current State

### 2.1 AIGeeks & Freaks Homepage

- **Stack:** Next.js 16, port 3800
- **Pages:** Home, Meetups, Courses, Shipped, Smíðja, Way of Teams, Login
- **Content:** All mock data (no real blog, no real content)
- **Auth:** None currently

### 2.2 Dirrty Mixbag Community

- **Stack:** Astro, Netlify, port 4321
- **Pages:** Home, Forum, Feed, Profile, Messages, Friends, News
- **Content:** Forum topics, feed posts, news articles
- **Auth:** Supabase Auth (email/password, GitHub/Google planned)
- **News Module:** Already exists at `/dirrtymixbag/news/` with index and article pages

---

## 3. Blog Architecture

### 3.1 Two-Tier Blog System

The blog exists in two places, linked together:

1. **AIGF Blog** — Primary content hub on `aigeeksnfreaks.zerwiz.org/blog`
   - Full blog posts with rich formatting
   - Course and meetup links
   - Builder attribution
   - SEO-optimized for search engines

2. **Dirrty Mixbag News** — Community discussion on `whynotproductions.netlify.app/dirrtymixbag/news`
   - Forum topics for each blog post
   - Community comments and discussion
   - Community member contributions
   - Cross-linked to AIGF blog

### 3.2 Content Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    CAPTAIN / COMMUNITY                       │
│                     Creates Blog Post                        │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
          ┌────────────────┐
          │  AIGF Blog     │
          │  (Primary)     │
          │                │
          │  - Full post   │
          │  - Code blocks │
          │  - Course links│
          │  - Meetup links│
          └────────┬───────┘
                   │
                   │ Cross-link
                   ▼
          ┌────────────────┐
          │ Dirrty Mixbag  │
          │ News / Forum   │
          │ (Discussion)   │
          │                │
          │  - Topic       │
          │  - Comments    │
          │  - Community   │
          │    contributions│
          └────────────────┘
```

---

## 4. Folder Structure

### 4.1 AIGF Blog Files

```
aigeeks&freeks/
├── data/
│   └── blog/
│       ├── agent-engineering/
│       │   ├── prompt-patterns-for-production-agents.md
│       │   ├── mcp-server-development-guide.md
│       │   └── multi-agent-orchestration-case-study.md
│       ├── courses/
│       │   ├── crs-100-launch.md
│       │   ├── crs-200-update.md
│       │   └── graduate-spotlight-kira.md
│       ├── meetups/
│       │   ├── w26-showcase-recap.md
│       │   ├── w27-2am-bug-fix-preview.md
│       │   └── community-highlights-october.md
│       ├── shipped/
│       │   ├── mcp-github-issues-deep-dive.md
│       │   ├── swarm-orchestrator-architecture.md
│       │   └── eval-harness-skill-lessons-learned.md
│       └── community/
│           ├── platform-update-october.md
│           ├── builder-spotlight-neo.md
│           └── milestone-1000-builders.md
```

### 4.2 Dirrty Mixbag Blog Files

```
WhyNotProductionsHomepage/
├── Dirrty Mixbag Homepage/
│   └── src/
│       └── pages/
│           └── dirrtymixbag/
│               └── blog/
│                   ├── agent-engineering/
│                   ├── courses/
│                   ├── meetups/
│                   ├── shipped/
│                   └── community/
```

---

## 5. Blog Post Format

### 5.1 Front Matter Fields

| Field | Required | Type | Description |
|---|---|---|---|
| `title` | Yes | string | Display title |
| `slug` | Yes | string | URL slug (e.g., `prompt-patterns-for-production-agents`) |
| `author` | Yes | string | Author display name |
| `authorProfile` | No | string | Dirrty Mixbag profile URL |
| `date` | Yes | ISO date | Publication date |
| `category` | Yes | string | Category: `agent-engineering`, `courses`, `meetups`, `shipped`, `community` |
| `tags` | Yes | array | Array of tag strings |
| `excerpt` | Yes | string | Short excerpt for listing |
| `featured` | No | boolean | Whether to feature on homepage (default: `false`) |
| `communityTopic` | No | boolean | Whether to create forum topic (default: `true`) |
| `communityTopicSlug` | No | string | Dirrty Mixbag forum topic slug |
| `courseCode` | No | string | Related course code |
| `meetupId` | No | string | Related meetup ID |
| `shipProject` | No | string | Related shipped project |

### 5.2 Example Blog Post

```markdown
---
title: "Prompt Patterns for Production Agents"
slug: "prompt-patterns-for-production-agents"
author: "Zerwiz"
authorProfile: "/dirrtymixbag/profile/zerwiz"
date: "2025-10-01"
category: "agent-engineering"
tags:
  - "prompt-engineering"
  - "production-agents"
  - "mcp"
excerpt: "A deep dive into prompt patterns that work reliably in production agent workflows."
featured: true
communityTopic: true
communityTopicSlug: "prompt-patterns-for-production-agents"
---

## Introduction

When building production agents, prompt engineering is not just about getting the right output — it's about getting consistent, reliable output at scale.

## The Problem

Most prompt engineering guides focus on single-shot examples. In production, you need patterns that work across thousands of requests.

## Pattern 1: Role-Based Prompts

[Content continues...]

## Related Resources

- [CRS-100: The 30-Min Feature Run](/courses/crs-100)
- [Join The 2 AM Bug Fix](/meetups/weekly-tue-2am-bug-fix)
- [Discussion on Dirrty Mixbag](/dirrtymixbag/news/prompt-patterns-for-production-agents)
```

---

## 6. AIGF Blog Pages

### 6.1 Blog Index Page (`/blog`)

- List of recent blog posts
- Category filters
- Tag filters
- Search functionality
- Pagination (10 posts per page)

### 6.2 Blog Post Page (`/blog/[slug]`)

- Full blog post content
- Author attribution
- Related posts
- Course and meetup links
- Dirrty Mixbag discussion link
- Comments section (linked to Dirrty Mixbag forum)

### 6.3 Category Pages (`/blog/[category]`)

- List of posts in category
- Category description
- Related courses and meetups

### 6.4 Tag Pages (`/blog/tag/[tag]`)

- List of posts with tag
- Tag description
- Related posts

---

## 7. Dirrty Mixbag News Pages

### 7.1 News Index (`/dirrtymixbag/news`)

- List of recent news articles
- Links to AIGF blog posts
- Community discussion preview

### 7.2 News Article (`/dirrtymixbag/news/[slug]`)

- Blog post excerpt
- Full article link to AIGF blog
- Community comments and discussion
- Related topics in forum

---

## 8. Content Creation Workflow

### 8.1 Weekly Content Calendar

| Day | Content Type | Source |
|---|---|---|
| Monday | Technical deep-dive | Captain writes |
| Wednesday | Course or meetup announcement | Captain writes |
| Friday | Shipped project showcase | Captain + builder input |
| Sunday | Community highlights | Captain + community input |

### 8.2 Content Creation Steps

1. **Topic Selection** (Monday morning)
   - Review upcoming courses and meetups
   - Check community questions and discussions
   - Select topic for the week

2. **Outline Creation** (Monday afternoon)
   - Create blog post outline
   - Define key points and examples
   - Identify code snippets needed

3. **Draft Writing** (Tuesday-Wednesday)
   - Write blog post draft
   - Include code examples
   - Add links to courses and meetups

4. **Review** (Thursday)
   - Captain reviews draft
   - Technical accuracy check
   - Tone and style check

5. **Publishing** (Friday)
   - Finalize blog post
   - Publish to AIGF blog
   - Create Dirrty Mixbag forum topic
   - Schedule social media posts

---

## 9. Integration with Dirrty Mixbag Community

### 9.1 Auth-Linked Content

When users are logged in via Dirrty Mixbag community:

- Comment on AIGF blog posts
- Create forum topics for blog posts
- Leave feedback on courses and meetups
- See which community members are reading which posts

### 9.2 Cross-Platform Features

- Blog posts link to Dirrty Mixbag discussions
- Dirrty Mixbag topics link to AIGF blog posts
- Community member contributions featured on AIGF blog
- Builder reputation carries across both platforms

---

## 10. Implementation Phases

### Phase 1: File Structure (Week 1)

- [ ] Create `data/blog/` directory structure in AIGF
- [ ] Create blog post template
- [ ] Create category directories
- [ ] Test file reading in Next.js

### Phase 2: Blog Pages (Week 2)

- [ ] Create blog index page (`/blog`)
- [ ] Create blog post page (`/blog/[slug]`)
- [ ] Create category pages (`/blog/[category]`)
- [ ] Create tag pages (`/blog/tag/[tag]`)

### Phase 3: Dirrty Mixbag Integration (Week 3)

- [ ] Add blog section to Dirrty Mixbag news
- [ ] Add forum topic creation on publish
- [ ] Add comment system integration
- [ ] Test cross-platform linking

### Phase 4: SEO and Polish (Week 4)

- [ ] Add SEO metadata to blog pages
- [ ] Add sitemap for blog posts
- [ ] Add RSS feed for blog
- [ ] Performance testing and optimization

---

## 11. Success Criteria

- [ ] Blog index page lists all posts
- [ ] Blog post pages render full content
- [ ] Category and tag filtering works
- [ ] Dirrty Mixbag forum topics created for each post
- [ ] Community members can comment on posts
- [ ] Course and meetup links in posts work
- [ ] SEO metadata on all blog pages
- [ ] Zero mock data in blog content

---

## 12. Success Metrics

| Metric | Target | Measurement |
|---|---|---|
| Blog posts published | 2/week | File count in `data/blog/` |
| Forum topics created | 2/week | Topic count in Dirrty Mixbag |
| Comments per post | 5+/week | Post count per topic |
| Blog traffic | 10%/month | Next.js analytics |
| Course enrollment from blog | 10%/month | Enrollment source tracking |
| Meetup attendance from blog | 15%/month | Attendance source tracking |

---

## 13. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Low community engagement | Medium | Active moderation + engagement prompts |
| Content policy violations | Medium | Pre-publish review + automated checks |
| Technical inaccuracies | High | Captain review + community feedback |
| Copyright issues | High | Original content only, proper attribution |
| Spam in comments | Medium | Moderation tools + rate limits |
