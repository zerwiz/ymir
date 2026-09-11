# AI Blog Posts in Dirty Mox Bag Community

**Status:** Planning  
**Last updated:** 2025-10-01  
**Projects:** AIGeeks & Freaks, Dirty Mox Bag Community

---

## 1. Goal

Create a system where AI-generated blog posts about agent engineering, MCP development, and swarm orchestration are published to the Dirty Mox Bag community forum. These posts serve as educational content, community engagement, and marketing for AIGeeks & Freaks courses and meetups.

---

## 2. Current State

### 2.1 Dirty Mox Bag Community

- **Forum:** Supabase-backed forum with topics and posts
- **Content Policy:** Function `community_content_allowed()` blocks spam and self-promotion
- **Authors:** Community members create topics and posts
- **Moderation:** RLS policies and moderation reports

### 2.2 AIGeeks & Freaks

- **Content:** No blog currently
- **Knowledge:** Course materials, meetup recordings, shipped projects
- **Audience:** Builders, developers, agent engineers

---

## 3. Blog Post Strategy

### 3.1 Content Pillars

All blog posts fall into one of these categories:

1. **Agent Engineering Deep Dives**
   - How to build effective agent workflows
   - Prompt engineering patterns for production agents
   - MCP server development tutorials
   - Multi-agent orchestration case studies

2. **Course Announcements & Updates**
   - New course launches
   - Course content updates
   - Graduate spotlights
   - Enrollment deadlines

3. **Meetup Recaps & Announcements**
   - What happened at last week's meetup
   - Upcoming meetup previews
   - Builder demos from sessions
   - Community highlights

4. **Shipped Project Showcases**
   - Deep dive into a recently shipped project
   - Lessons learned from the build process
   - Architecture decisions and trade-offs
   - Code walkthroughs

5. **Community News & Updates**
   - Platform updates
   - New features
   - Community milestones
   - Builder spotlights

### 3.2 Posting Frequency

- **Weekly:** 1-2 deep-dive technical posts
- **Bi-weekly:** 1 course or meetup announcement
- **Monthly:** 1 shipped project showcase
- **As-needed:** Community news and updates

### 3.3 Author Attribution

- Posts authored by the AIGF team (captain as primary author)
- Community members can co-author posts
- Posts linked to Dirty Mox Bag community profiles
- GitHub integration for builder attribution

---

## 4. Technical Implementation

### 4.1 Blog Post Storage

Store blog posts as Markdown files in the Dirty Mox Bag project:

```
WhyNotProductionsHomepage/
├── dirrtymixbag/
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

### 4.2 Blog Post Format

Each blog post is a Markdown file with YAML front matter:

```markdown
---
title: "Prompt Patterns for Production Agents"
slug: "prompt-patterns-for-production-agents"
author: "Zerwiz"
authorProfile: "dirrtymixbag/profile/zerwiz"
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
```

### 4.3 Publishing Flow

1. **Draft Creation**
   - Write blog post as Markdown file
   - Add front matter with metadata
   - Store in appropriate category directory

2. **Review**
   - Captain reviews draft
   - Community moderators can comment on draft
   - Edits made as needed

3. **Publishing**
   - Set `published: true` in front matter
   - Create corresponding forum topic in Dirty Mox Bag
   - Link forum topic to blog post
   - Notify community members

4. **Distribution**
   - Post to community forum
   - Share on social media (Postiz integration)
   - Email to course subscribers (Mautic integration)

### 4.4 Forum Topic Integration

Each published blog post creates a corresponding forum topic:

- Topic title matches blog post title
- Topic body contains excerpt and link to full post
- Topic tags match blog post tags
- Topic author is the blog post author
- Topic is pinned to relevant category

---

## 5. AI Generation Workflow

### 5.1 Content Generation Process

1. **Topic Selection**
   - Review upcoming courses and meetups
   - Identify knowledge gaps in community
   - Check trending topics in agent engineering
   - Select 2-3 topics for next week

2. **Outline Creation**
   - Create blog post outline
   - Define key points and examples
   - Identify code snippets needed
   - Define target audience level

3. **Draft Generation**
   - Write blog post draft
   - Include code examples where relevant
   - Add links to courses and meetups
   - Keep tone technical but accessible

4. **Review and Edit**
   - Captain reviews draft
   - Technical accuracy check
   - Tone and style check
   - Community policy compliance check

5. **Publishing**
   - Finalize blog post
   - Create forum topic
   - Schedule social media posts
   - Update community feed

### 5.2 AI-Assisted Writing

Use AI to assist with:

- **Research:** Gather latest information on topics
- **Outline Generation:** Create structured outlines
- **Draft Writing:** Generate initial drafts
- **Code Examples:** Create working code examples
- **Review:** Check for technical accuracy
- **Editing:** Improve clarity and readability

### 5.3 Human-in-the-Loop

AI assists but humans decide:

- **Topic Selection:** Captain chooses topics
- **Outline Approval:** Captain approves outlines
- **Draft Review:** Captain reviews all drafts
- **Final Edit:** Captain makes final edits
- **Publishing Decision:** Captain decides when to publish

---

## 6. Community Engagement

### 6.1 Commenting System

- Enable comments on blog posts
- Comments stored in community forum
- Comments linked to community profiles
- Moderation tools for comments

### 6.2 Discussion Topics

- Each blog post creates a discussion topic
- Community members can ask questions
- Authors can answer questions
- Best answers pinned to top

### 6.3 Builder Contributions

- Community members can submit guest posts
- Guest posts reviewed by captain
- Guest authors get community profile links
- Guest posts follow same format

### 6.4 Course and Meetup Links

- Blog posts link to relevant courses
- Blog posts link to upcoming meetups
- Course enrollment links in posts
- Meetup registration links in posts

---

## 7. Integration with Marketing Stack

### 7.1 Postiz (Social Media)

- Schedule social media posts for each blog
- Auto-generate tweet threads from blog posts
- Schedule LinkedIn posts for technical audience
- Schedule YouTube shorts for key points

### 7.2 Mautic (Email)

- Add blog subscribers to mailing list
- Send weekly digest of new posts
- Send course announcements with blog links
- Send meetup recaps with blog links

### 7.3 Activepieces (Automation)

- Auto-create forum topic when blog published
- Auto-notify subscribers of new posts
- Auto-archive old posts after 6 months
- Auto-generate social media posts

---

## 8. Implementation Phases

### Phase 1: File Structure (Week 1)

- [ ] Create `dirrtymixbag/blog/` directory structure
- [ ] Create blog post template
- [ ] Create category directories
- [ ] Test file reading in Astro

### Phase 2: Forum Integration (Week 2)

- [ ] Add forum topic creation on publish
- [ ] Add blog post to forum topic linking
- [ ] Add comment system integration
- [ ] Test community engagement flow

### Phase 3: AI Workflow (Week 3)

- [ ] Create AI-assisted writing workflow
- [ ] Create topic selection process
- [ ] Create review and editing process
- [ ] Test end-to-end publishing flow

### Phase 4: Marketing Integration (Week 4)

- [ ] Connect Postiz for social media
- [ ] Connect Mautic for email
- [ ] Connect Activepieces for automation
- [ ] Test full marketing automation

---

## 9. Success Criteria

- [ ] Blog posts published weekly
- [ ] Forum topics created for each post
- [ ] Community members commenting on posts
- [ ] Course enrollment increasing from blog traffic
- [ ] Meetup attendance increasing from blog traffic
- [ ] Social media engagement increasing
- [ ] Email subscriber count increasing
- [ ] Zero spam or policy violations

---

## 10. Success Metrics

| Metric | Target | Measurement |
|---|---|---|
| Blog posts published | 2/week | File count in `blog/` |
| Forum topics created | 2/week | Topic count in forum |
| Comments per post | 5+/week | Post count per topic |
| Course enrollment from blog | 10%/month | Enrollment source tracking |
| Meetup attendance from blog | 15%/month | Attendance source tracking |
| Social media engagement | 20%/month | Postiz analytics |
| Email subscribers | 5%/week | Mautic subscriber count |
| Spam rate | <1% | Moderation reports |

---

## 11. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| AI-generated content quality | Medium | Human review of all drafts |
| Spam in comments | Medium | Moderation tools + rate limits |
| Copyright issues | High | Original content only, proper attribution |
| Technical inaccuracies | High | Captain review + community feedback |
| Low community engagement | Medium | Active moderation + engagement prompts |
| Content policy violations | Medium | Pre-publish review + automated checks |
