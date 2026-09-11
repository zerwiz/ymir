# AIGeeks & Freaks — Master Planning Index

**Status:** Planning  
**Last updated:** 2025-10-01  
**Projects:** AIGeeks & Freaks, Dirrty Mixbag Community, WhyNot Productions

---

## Overview

This document indexes all planning documents for the AIGeeks & Freaks real data migration, authentication integration, blog system, and content management skill. All work is text-only planning — no code yet.

---

## Planning Documents

### 1. Real Data Migration Plan

**Path:** `data/aigf-real-data-migration-plan.md`  
**Covers:** Database schema, API routes, mock data inventory, migration phases

**Key Points:**
- Replace all mock data arrays with real database queries
- New Prisma schema: `User`, `Course`, `Event`, `Ship`, `Agent`, `Workspace`, etc.
- API routes for hero metrics, meetups, courses, shipped items
- 6-phase migration: Foundation → Meetups → Courses → Shipped → Join CTA → Integration
- Estimated effort: 17-23 days

### 2. Courses & Meetups File Structure

**Path:** `data/aigf-courses-meetups-file-structure.md`  
**Covers:** One-file-per-course and one-file-per-meetup folder structure

**Key Points:**
- Folder structure: `data/courses/`, `data/meetups/`, `data/meetups/archive/`
- YAML front matter + Markdown body for each file
- Build-time or runtime file reading strategy
- Admin workflow for creating, updating, archiving content
- Integration with Dirrty Mixbag community auth

### 3. GitHub & Google Login Plan

**Path:** `data/aigf-github-google-login-plan.md`  
**Covers:** Supabase Auth integration, OAuth configuration, multi-tenant profile sync

**Key Points:**
- Single Supabase project handles auth for both platforms
- GitHub and Google OAuth providers
- Multi-tenant profile model (`dirrtymixbag` + `aigf`)
- 4-phase implementation: OAuth config → Frontend → Profile sync → AIGF features
- Security: PKCE flow, JWT sessions, RLS policies, rate limiting

### 4. AI Blog Posts in Dirrty Mixbag

**Path:** `data/aigf-ai-blog-posts-in-community.md`  
**Covers:** Blog content strategy, AI-assisted writing workflow, community engagement

**Key Points:**
- 5 content pillars: Agent Engineering, Courses, Meetups, Shipped Projects, Community News
- Blog posts stored as Markdown files in `dirrtymixbag/blog/`
- AI-assisted writing with human-in-the-loop review
- Forum topic integration for each post
- Marketing stack integration: Postiz, Mautic, Activepieces

### 5. Blog on AIGF Site

**Path:** `data/aigf-blog-in-aigf-site.md`  
**Covers:** AIGF blog pages, Dirrty Mixbag news integration, content flow

**Key Points:**
- Two-tier blog system: AIGF blog (primary) + Dirrty Mixbag news (discussion)
- Blog files in `aigeeks&freeks/data/blog/`
- Pages: Blog index, post page, category pages, tag pages
- Content flow: Captain writes → AIGF blog → Dirrty Mixbag forum topic
- SEO optimization, sitemap, RSS feed

### 6. Blog Management Skill

**Path:** `data/aigf-blog-management-skill.md`  
**Covers:** Captain-facing skill for creating/editing/publishing blog posts

**Key Points:**
- Skill name: `aigf-blog-manager`
- Commands: `/blog create`, `/blog edit`, `/blog list`, `/blog archive`, `/blog schedule`, `/blog publish`
- Natural language workflow: Captain describes topic → AI generates outline → Captain approves → AI generates draft → Captain approves → Publish
- Integration with AIGF blog, Dirrty Mixbag, marketing stack, GitHub

---

## How It All Fits Together

```
┌─────────────────────────────────────────────────────────────────┐
│                      CAPTAIN'S WORKFLOW                         │
│                                                                 │
│  /blog create "Prompt patterns"                                 │
│  /blog edit "Add section on X"                                  │
│  /blog list --category agent-engineering                        │
│                                                                 │
└──────────┬──────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BLOG MANAGEMENT SKILL                         │
│                    (aigf-blog-manager)                           │
│                                                                 │
│  - Generates outline from natural language                      │
│  - Generates draft from approved outline                        │
│  - Publishes to AIGF blog and Dirrty Mixbag                     │
│  - Schedules social media posts                                 │
│  - Sends email notifications                                    │
└──────────┬──────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AIGF BLOG (Primary)                          │
│                    aigeeksnfreaks.zerwiz.org/blog                │
│                                                                 │
│  - Full blog posts with rich formatting                         │
│  - Course and meetup links                                      │
│  - Builder attribution via GitHub                               │
│  - SEO-optimized for search engines                             │
│  - File-based: data/blog/*.md                                   │
└──────────┬──────────────────────────────────────────────────────┘
           │
           │ Cross-link
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                 DIRRTY MIXBAG NEWS / FORUM                      │
│              whynotproductions.netlify.app/dirrtymixbag          │
│                                                                 │
│  - Forum topic for each blog post                               │
│  - Community comments and discussion                            │
│  - Community member contributions                               │
│  - Supabase-backed with RLS                                     │
│  - Auth: GitHub, Google, email/password                         │
└──────────┬──────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MARKETING STACK                              │
│                                                                 │
│  - Postiz: Social media scheduling                              │
│  - Mautic: Email notifications                                  │
│  - Activepieces: Automation                                     │
│  - GitHub: Builder attribution                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Order

### Phase 0: Foundation (Week 1)

1. **Database Schema** — `aigf-real-data-migration-plan.md` Phase 1
   - Create Prisma schema with all models
   - Set up PostgreSQL database
   - Run migrations
   - Seed initial data

2. **File Structure** — `aigf-courses-meetups-file-structure.md`
   - Create `data/courses/` and `data/meetups/` directories
   - Convert existing mock data to files
   - Test file reading

3. **Blog Structure** — `aigf-blog-in-aigf-site.md`
   - Create `data/blog/` directory structure
   - Create blog post template
   - Test file reading in Next.js

### Phase 1: Authentication (Week 2)

4. **GitHub & Google Login** — `aigf-github-google-login-plan.md` Phase 1-2
   - Create GitHub OAuth application
   - Create Google OAuth application
   - Configure Supabase providers
   - Add login buttons to both platforms

### Phase 2: Content System (Week 3)

5. **API Routes** — `aigf-real-data-migration-plan.md` Phase 1-2
   - Create `/api/status` endpoint
   - Create `/api/events` endpoint
   - Create `/api/courses` endpoint
   - Create `/api/ships` endpoint

6. **Blog Pages** — `aigf-blog-in-aigf-site.md` Phase 2
   - Create blog index page (`/blog`)
   - Create blog post page (`/blog/[slug]`)
   - Create category pages
   - Create tag pages

### Phase 3: Community Integration (Week 4)

7. **Dirrty Mixbag Integration** — `aigf-ai-blog-posts-in-community.md`
   - Add blog section to Dirrty Mixbag news
   - Add forum topic creation on publish
   - Add comment system integration

8. **Blog Management Skill** — `aigf-blog-management-skill.md` Phase 1-2
   - Create skill directory and SKILL.md
   - Implement `/blog create` command
   - Implement outline generation
   - Implement draft generation
   - Implement publishing

### Phase 4: Marketing Integration (Week 5)

9. **Marketing Stack** — `aigf-ai-blog-posts-in-community.md` Phase 4
   - Connect Postiz for social media
   - Connect Mautic for email
   - Connect Activepieces for automation

10. **GitHub Integration** — `aigf-github-google-login-plan.md` Phase 3
    - Link GitHub commits to user profiles
    - Show builder reputation on AIGF pages
    - Enable community forum topics per course/meetup

### Phase 5: Polish (Week 6)

11. **SEO and Performance** — `aigf-blog-in-aigf-site.md` Phase 4
    - Add SEO metadata to blog pages
    - Add sitemap for blog posts
    - Add RSS feed for blog
    - Performance testing and optimization

12. **Skill Polish** — `aigf-blog-management-skill.md` Phase 3-4
    - Implement `/blog edit` command
    - Implement `/blog list` command
    - Implement `/blog archive` command
    - Implement `/blog schedule` command
    - Implement `/blog publish` command

---

## Success Criteria Summary

| Area | Success Criteria | Document |
|---|---|---|
| Database | Zero mock data arrays remain | `aigf-real-data-migration-plan.md` |
| Auth | Users can log in with GitHub or Google | `aigf-github-google-login-plan.md` |
| Courses | Each course has its own file | `aigf-courses-meetups-file-structure.md` |
| Meetups | Each meetup has its own file | `aigf-courses-meetups-file-structure.md` |
| Blog | Blog posts published weekly | `aigf-ai-blog-posts-in-community.md` |
| Blog Pages | Blog index, post, category, tag pages work | `aigf-blog-in-aigf-site.md` |
| Community | Forum topics created for each post | `aigf-ai-blog-posts-in-community.md` |
| Skill | Captain can create posts with natural language | `aigf-blog-management-skill.md` |
| Marketing | Social media, email, automation integrated | `aigf-ai-blog-posts-in-community.md` |
| Attribution | Builder reputation linked to GitHub | `aigf-github-google-login-plan.md` |

---

## Next Steps

1. **Captain review** — Review all planning documents and provide feedback
2. **Prioritize** — Decide which areas to tackle first
3. **Approve** — Give approval to start implementation
4. **Execute** — Begin Phase 0: Foundation

---

## File Index

All planning documents are stored in `/home/zerwiz/firstmate/data/`:

| File | Purpose |
|---|---|
| `aigf-real-data-migration-plan.md` | Database schema, API routes, mock data migration |
| `aigf-courses-meetups-file-structure.md` | One-file-per-course and one-file-per-meetup structure |
| `aigf-github-google-login-plan.md` | GitHub and Google login integration |
| `aigf-ai-blog-posts-in-community.md` | AI blog posts in Dirrty Mixbag community |
| `aigf-blog-in-aigf-site.md` | Blog on AIGF site with Dirrty Mixbag integration |
| `aigf-blog-management-skill.md` | Blog management skill for captain's workflow |
| `discord-server-integration-planning.md` | Discord server integration planning (existing) |
| `ecosystem-planning.md` | Ecosystem planning (existing) |
