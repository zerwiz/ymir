# Courses & Meetups — File-per-Item Folder Structure

**Status:** Planning  
**Last updated:** 2025-10-01  
**Projects:** AIGeeks & Freaks (`/home/zerwiz/CodeP/aigeeks&freeks`)

---

## 1. Goal

Replace the hardcoded `EVENTS`, `COURSES`, and related mock arrays with one-file-per-course and one-file-per-meetup text documents. Each file is a single source of truth for that course or meetup — title, description, outcome, schedule, prerequisites, and metadata. The frontend reads these files at build time or runtime to populate the catalog and event listings.

---

## 2. Folder Structure

```
aigeeks&freeks/
├── data/
│   ├── courses/
│   │   ├── CRS-100.md
│   │   ├── CRS-200.md
│   │   ├── CRS-300.md
│   │   └── CRS-400.md
│   └── meetups/
│       ├── weekly-tue-2am-bug-fix.md
│       ├── monthly-fri-showcase.md
│       ├── quarterly-masterclass.md
│       └── archive/
│           ├── W26-showcase-night-5.md
│           ├── W25-mcp-deep-dive.md
│           └── W24-smidja-workshop.md
```

---

## 3. Course File Format

Each course file is a Markdown document with a YAML front matter block and a body section.

### 3.1 Front Matter Fields

| Field | Required | Type | Description |
|---|---|---|---|
| `code` | Yes | string | Unique course code (e.g., `CRS-100`) |
| `title` | Yes | string | Display title |
| `outcome` | Yes | string | One-sentence learning outcome |
| `level` | Yes | string | Level label (e.g., `LVL 100`) |
| `lvlColor` | Yes | string | Color token: `lime`, `cyan`, `amber` |
| `stack` | Yes | array | Array of tool names (e.g., `["Claude Code", "Cursor"]`) |
| `duration` | Yes | string | Duration label (e.g., `3h · self-paced`) |
| `lessons` | Yes | integer | Number of lessons |
| `price` | Yes | string | Price display (e.g., `$0`, `$49`) |
| `priceNote` | No | string | Price note (e.g., `open access`) |
| `includes` | Yes | string | Included infrastructure |
| `prereq` | No | string | Prerequisites |
| `status` | No | string | `active`, `draft`, `archived` (default: `active`) |
| `featured` | No | boolean | Whether to highlight in catalog (default: `false`) |
| `path` | No | array | Array of path step labels |
| `createdAt` | No | ISO date | Creation date |
| `updatedAt` | No | ISO date | Last update date |

### 3.2 Body Section

The body contains the full course description, lesson-by-lesson breakdown, and any additional context. This is what gets rendered on the course detail page.

### 3.3 Example Course File

```markdown
---
code: "CRS-100"
title: "The 30-Min Feature Run"
outcome: "Take a fuzzy feature request from idea to merged PR in one focused 30-minute loop — prompt, plan, code, review, ship."
level: "LVL 100"
lvlColor: "lime"
stack:
  - "Claude Code"
  - "Cursor"
  - "OpenCode"
duration: "3h · self-paced"
lessons: 14
price: "$0"
priceNote: "open access"
includes: "Community Discord + shared OpenChamber sandbox"
prereq: "None — a browser and an idea are enough."
status: "active"
featured: false
path:
  - "Prompt"
  - "Plan"
  - "Code"
  - "Review"
  - "Ship"
---

## Overview

This course teaches you to take a feature request from zero to merged PR in a single focused session. You will learn the prompt-to-ship loop that turns fuzzy requirements into working code.

## What You Will Learn

- How to write prompts that produce working code on the first try
- Planning strategies for 30-minute feature sprints
- Code review patterns that catch real bugs
- Ship workflows that merge to main without breaking CI

## Lesson Breakdown

1. **The one-prompt loop** (15m) — Write prompts that produce working code
2. **Planning the feature** (20m) — Break down requirements into actionable steps
3. **Code generation patterns** (30m) — Prompt patterns for different code styles
4. **Review and iterate** (25m) — How to review AI-generated code effectively
5. **Ship to main** (15m) — Merge workflows and CI gates

## Included Infrastructure

Community Discord + shared OpenChamber sandbox

## Price

$0 — open access
```

---

## 4. Meetup File Format

Each meetup file is a Markdown document with a YAML front matter block and a body section.

### 4.1 Front Matter Fields

| Field | Required | Type | Description |
|---|---|---|---|
| `id` | Yes | string | Unique identifier (slug) |
| `title` | Yes | string | Display title |
| `kind` | Yes | string | Event type: `weekly`, `monthly`, `masterclass`, `showcase`, `one-off` |
| `description` | Yes | string | Full event description |
| `hostName` | No | string | Host display name |
| `status` | No | string | `upcoming`, `live`, `completed`, `cancelled` (default: `upcoming`) |
| `isRecurring` | No | boolean | Whether this is a recurring event (default: `false`) |
| `recurrence` | No | string | Recurrence pattern (e.g., `weekly-tue`, `monthly-first-fri`) |
| `dayOfWeek` | No | string | Day abbreviation (e.g., `TUE`, `FRI`) |
| `time` | No | string | Start time (e.g., `02:00`, `19:00`) |
| `timezone` | No | string | Timezone (default: `CET`) |
| `startDate` | No | ISO date | First occurrence date |
| `endDate` | No | ISO date | Last occurrence date (for finite series) |
| `replayUrl` | No | string | YouTube or recording URL |
| `viewCount` | No | integer | Number of views (default: `0`) |
| `maxAttendees` | No | integer | Capacity limit |
| `discordChannelId` | No | string | Discord channel ID for this event |
| `createdAt` | No | ISO date | Creation date |
| `updatedAt` | No | ISO date | Last update date |

### 4.2 Body Section

The body contains the full event description, agenda, what to bring, and any additional context. This is what gets rendered on the event detail page.

### 4.3 Example Upcoming Meetup File

```markdown
---
id: "weekly-tue-2am-bug-fix"
title: "The 2 AM Bug Fix"
kind: "weekly"
description: "Live screen-share office hours every Tuesday at 2 AM CET. Bring a stuck agent, a half-built demo, or a bug that won't reproduce. We'll pair on it together."
hostName: "The Smíðja"
status: "upcoming"
isRecurring: true
recurrence: "weekly-tue"
dayOfWeek: "TUE"
time: "02:00"
timezone: "CET"
maxAttendees: 40
discordChannelId: "channel-id-here"
---

## What Happens

Live screen-share office hours where builders bring their hardest problems and get help in real time. This is not a presentation — it's a working session.

## What to Bring

- A stuck agent that won't cooperate
- A half-built demo that needs finishing
- A bug that only reproduces on Tuesdays
- A PR review you want done live

## How It Works

1. Join the Discord voice channel at the scheduled time
2. Share your screen and describe the problem
3. The community pairs with you to solve it
4. If it ships, it goes on the wall

## Replay

Past sessions are recorded and linked here when available.
```

### 4.4 Example Archive Meetup File

```markdown
---
id: "W26-showcase-night-5"
title: "W26 Showcase Night #5"
kind: "showcase"
description: "Fifth showcase night of the year. Three builders demo what they shipped in the previous week."
hostName: "Showcase Committee"
status: "completed"
startDate: "2025-06-28T19:00:00Z"
endDate: "2025-06-28T21:00:00Z"
replayUrl: "https://youtube.com/watch?v=example"
viewCount: 342
maxAttendees: 40
---

## Agenda

- 19:00 — Doors open, Discord voice channel active
- 19:15 — Welcome and rules
- 19:20 — Builder 1 demo (10 min)
- 19:30 — Builder 2 demo (10 min)
- 19:40 — Builder 3 demo (10 min)
- 19:50 — Open Q&A
- 20:30 — Wrap and next showcase announcement

## Shown This Session

- @kira — mcp-github-issues
- @neo — swarm-orchestrator
- @holt — eval-harness-skill
```

---

## 5. File Reading Strategy

### 5.1 Build-Time Reading (Static Generation)

At build time, the Next.js app reads all files in `data/courses/` and `data/meetups/`, parses the front matter, and generates static pages or API responses. This is the default path for production.

### 5.2 Runtime Reading (Dynamic Content)

For admin-created or frequently updated content, the app reads files at runtime on each request. This adds a small overhead but allows instant updates without rebuilds.

### 5.3 Hybrid Approach

Build-time for stable content (courses, past events), runtime for active content (upcoming events, live status). This gives the best of both worlds.

---

## 6. Admin Workflow

### 6.1 Creating a New Course

1. Copy an existing course file from `data/courses/`
2. Update the front matter fields
3. Write the body section
4. Set `status: "active"` when ready to publish

### 6.2 Creating a New Meetup

1. Copy an existing meetup file from `data/meetups/`
2. Update the front matter fields
3. Write the body section
4. Set `status: "upcoming"` for future events

### 6.3 Archiving a Past Meetup

1. Open the meetup file
2. Change `status` from `upcoming` to `completed`
3. Add the `replayUrl` when the recording is available
4. Move the file to `data/meetups/archive/`

---

## 7. Integration with Dirty Mox Bag Community

### 7.1 Auth-Linked Content

When users are logged in via the Dirty Mox Bag community (Supabase Auth), they can:

- Comment on course pages
- Leave feedback on meetup pages
- Create subtopics in the community forum linked to specific courses or meetups
- See which community members are enrolled in which courses

### 7.2 Cross-Platform Features

- Course enrollment tracked in community profiles
- Meetup attendance tracked in community profiles
- AI blog posts (see separate document) linked to both platforms
- Builder reputation carries across both communities

---

## 8. Migration Path

### Phase 1: File Structure Setup

- Create `data/courses/` and `data/meetups/` directories
- Convert existing mock data arrays to individual files
- Verify file reading works in development

### Phase 2: Frontend Integration

- Update course catalog page to read from files
- Update meetup listing page to read from files
- Add course detail and meetup detail pages
- Add admin interface for file management

### Phase 3: Community Integration

- Link community auth to course/meetup interactions
- Add community forum topics for each course and meetup
- Enable cross-platform reputation

---

## 9. Success Criteria

- [ ] Every course has its own file in `data/courses/`
- [ ] Every meetup has its own file in `data/meetups/`
- [ ] Past meetups are archived in `data/meetups/archive/`
- [ ] Frontend reads files and displays correct data
- [ ] Admin can create/update/archive content via files
- [ ] Community auth is linked to course/meetup interactions
- [ ] Zero mock data arrays remain in any component
