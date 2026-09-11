# AI Geeks & Freaks — Real Data Migration Plan

**Status:** Planning  
**Last updated:** 2025-10-01  
**Project:** `/home/zerwiz/CodeP/aigeeks&freeks`  
**Homepage:** `aigeeksnfreaks.zerwiz.org` (Next.js 16, port 3800)

---

## 1. Problem Statement

The AIGeeks & Freaks homepage currently displays **all mock data** — hardcoded arrays, `Math.random()` generators, and static strings. There is **zero real data** flowing from any backend. The Prisma schema has only `User` and `Post` models with no application-specific tables.

**Goal:** Replace every mock data source with real, queryable data from a proper database schema, backed by API routes, with data entry points from Discord, the marketing stack (Mautic/Activepieces), and manual admin operations.

---

## 2. Current Mock Data Inventory

### 2.1 Hero Section (`src/components/site/hero.tsx`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| `TICKER` array (8 items) | Static strings: "12 AGENTS ACTIVE", "1,284 BUILDS SHIPPED", etc. | Live system status from agent registry, build pipeline, workspace pool |
| "12 agents active" | Hardcoded | `Agent` model — count of active agents |
| "1,284 builds shipped" | Hardcoded | `Ship` model — count of completed ships |
| "6 workspaces live" | Hardcoded | `Workspace` model — count of active workspaces |
| "2,140 builders online" | Hardcoded | `User` model — count of active builders |
| "28m avg build" | Hardcoded | `Ship` model — average build time |
| "12 seats left" (alpha) | Hardcoded | `Cohort` model — remaining seats |

### 2.2 Community Metrics (`src/components/site/community-metrics.tsx`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| `METRICS` array (6 items) | Static: "2,140 Builders", "1,284 Shipped", "12 Agents", "40 Cohort cap", "96.1% Success Rate", "+12% MoM" | Aggregated from `User`, `Ship`, `Agent`, `Cohort`, `Workspace` models |
| `TICKER_ITEMS` array (12 items) | Static strings: "@kira shipped mcp-weather-skill", etc. | Live `Ship` feed — recent completed ships |

### 2.3 Meetups Page (`src/components/pages/meetups-content.tsx`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| `EVENTS` array (3 items) | Hardcoded events: "The 2 AM Bug Fix", "Geek & Freak Showcases", "Factory Workshop: MCP Deep Dive" | `Event` model — recurring and one-off events with host, schedule, status |
| `ARCHIVE` array (8 items) | Static: "W26 Showcase night #5", view counts | `Event` model — past events with replay URLs and view counts |
| `CHANNELS` array (8 items) | Static Discord channels with member counts | `DiscordChannel` model — synced from Discord API |
| `BRING` array (4 items) | Static: "A stuck agent", "A half-built demo", etc. | **No change needed** — this is static marketing copy |
| `HOST_PERKS` array (3 items) | Static: "Host a session", "Founding-member flair", "Recognition" | **No change needed** — static marketing copy |
| `FAQ` array (5 items) | Static FAQ | **No change needed** — static marketing copy |
| `LEADERS` array (5 items) | Static: "@kira 24 ships", "@neo 21 ships", etc. | `User` model — leaderboard by ship count |
| Community stats strip | "1,200+ members", "100+ live sessions", "80k replay views", "40 builders cap" | Aggregated from `User`, `Event`, `Ship` models |

### 2.4 Courses Page (`src/components/pages/courses-content.tsx`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| `COURSES` array (4 items) | Hardcoded: CRS-100 through CRS-400 with prices, outcomes, stacks | `Course` model — full course catalog with pricing, prerequisites, status |
| `SYLLABUS` array (4 modules) | Static lesson lists | `Lesson` model — linked to `Course` |
| `COHORT` array (4 items) | Static: "OCT 05, 18/40 seats" | `Cohort` model — active cohorts with enrollment counts |
| `QUOTES` array (3 items) | Static testimonials: "@vee", "@rune", "@sachi" | `Testimonial` model — verified graduate quotes |
| `FAQ` array (5 items) | Static FAQ | **No change needed** — static marketing copy |
| Academy stats strip | "700+ builders graduated", "21h curriculum", "70+ lessons", "100% ship" | Aggregated from `User`, `Course`, `Lesson`, `Ship` models |

### 2.5 Wall of Shipped (`src/components/site/wall-of-shipped.tsx`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| `mkShip()` function | `Math.random()` generates random builder, project, commit hash, branch, build time, LOC, agents | `Ship` model — real git commits from GitHub integration |
| `BUILDERS` array (14 names) | Static: "@kira", "@neo", etc. | `User` model — active builders |
| `PROJECTS` array (12 items) | Static project names | `Project` model — shipped projects |
| `totalShipped` state | Starts at 1284, increments via `setInterval` | `Ship` model — `COUNT(*)` |
| Live feed (14 items) | Random ships every 4.2s | Real-time `Ship` feed via API polling or SSE |
| Side stats | "Avg build: 28m", "Agents/run: 8.4", "Today: 42", "Velocity: +12%" | Aggregated from `Ship` model |
| Top stacks | "claude-code 92%", "cursor 74%", etc. | `Ship` model — stack distribution |

### 2.6 Shipped Page (`src/components/pages/shipped-content.tsx`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| `mkShip()` function | Same random generator as wall-of-shipped | `Ship` model |
| `BUILDERS` array (20 names) | Static | `User` model |
| `PROJECTS_BY_CATEGORY` (5 categories) | Static project lists | `Project` model with `category` field |
| `STATS` array (6 items) | Static: "1,284 all-time", "47 this week", etc. | Aggregated from `Ship` model |
| `TOP_SHIPPERS` array (8 items) | Static leaderboard | `User` model — ranked by ship count |
| `MARQUEE_PROJECTS` array (20 items) | Static project names | `Project` model — recent ships |
| Category counts | "10 more in feed" | `Project` model — count per category |

### 2.7 Footer (`src/components/site/footer.tsx`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| "all systems nominal" | Static | System health check endpoint |
| "build 0xa1f9c2" | Static | Current deployment commit hash |
| "latency 14ms" | Static | Health check response time |
| "© 2025" | `new Date().getFullYear()` | **No change needed** — already dynamic |

### 2.8 Homepage Meetups Section (`src/components/site/meetups.tsx`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| `EVENTS` array (3 items) | Same hardcoded events as meetups page | `Event` model |
| `ARCHIVE` array (8 items) | Same hardcoded archive | `Event` model — past events |
| Community stats | "1,200+ members on stage", "100+ live sessions", "80k replay views", "40 builders cap" | Aggregated from `User`, `Event`, `Ship` models |

### 2.9 Homepage Academy Section (`src/components/site/academy.tsx`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| `COURSES` array (3 items) | CRS-100, CRS-200, CRS-300 (missing CRS-400) | `Course` model — full catalog |

### 2.10 Homepage Join CTA (`src/components/site/footer.tsx` — `JoinCta`)

| Mock Element | Current Value | Real Source Needed |
|---|---|---|
| "12 seats remaining" | Hardcoded | `Cohort` model — remaining seats |
| "Builders: 2,140", "Shipped: 1,284", "Agents: 12", "Cohort cap: 40" | Hardcoded | Aggregated from `User`, `Ship`, `Agent`, `Cohort` models |

---

## 3. Required Database Schema

### 3.1 Prisma Schema (`prisma/schema.prisma`)

```prisma
// === USERS & COMMUNITY ===

model User {
  id            String   @id @default(cuid())
  email         String?  @unique
  name          String?
  discordId     String?  @unique
  githubId      String?  @unique
  role          String   @default("member") // member, builder, host, moderator, admin
  isGraduate    Boolean  @default(false)
  enrolledCourses String[] @default([]) // course codes
  shipCount     Int      @default(0)
  totalLoc      Int      @default(0)
  successRate   Float    @default(0)
  stack         String   @default("claude") // claude, cursor, opencode, jido
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  lastActive    DateTime @default(now())

  ships         Ship[]
  events        EventAttendee[]
  testimonials  Testimonial[]
}

// === COURSES ===

model Course {
  id            String   @id @default(cuid())
  code          String   @unique // CRS-100, CRS-200, etc.
  title         String
  outcome       String
  level         String   // LVL 100, LVL 200, etc.
  lvlColor      String   // lime, cyan, amber
  stack         String[] // ["Claude Code", "Cursor", "OpenCode"]
  duration      String   // "3h · self-paced"
  lessonCount   Int      @default(0)
  price         Float    @default(0)
  priceNote     String?  // "open access", "with Pro+ plan"
  includes      String   // "Community Discord + shared OpenChamber sandbox"
  prereq        String   // "None — a browser and an idea are enough."
  path          String[] // ["Prompt", "Plan", "Code", "Review", "Ship"]
  status        String   @default("active") // active, draft, archived
  featured      Boolean  @default(false)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  lessons       Lesson[]
  cohorts       Cohort[]
  enrollments   Enrollment[]
  ships         Ship[]
}

model Lesson {
  id            String   @id @default(cuid())
  courseCode    String
  module        String   // CRS-100, CRS-200, etc.
  order         Int      // 1, 2, 3...
  title         String   // "01 · The one-prompt loop"
  description   String
  duration      String?  // "15m", "2h"
  content       String?  // markdown content
  videoUrl      String?
  isPublished   Boolean  @default(false)

  course        Course   @relation(fields: [courseCode], references: [id])

  @@unique([courseCode, order])
}

model Cohort {
  id            String   @id @default(cuid())
  courseCode    String
  startDate     DateTime
  endDate       DateTime?
  maxSeats      Int
  enrolledSeats Int      @default(0)
  status        String   @default("open") // open, full, cancelled, completed
  isLive        Boolean  @default(false)
  replayUrl     String?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  course        Course   @relation(fields: [courseCode], references: [id])
  enrollments   Enrollment[]

  @@index([courseCode, status])
}

model Enrollment {
  id            String   @id @default(cuid())
  userId        String
  courseCode    String
  cohortId      String?
  enrolledAt    DateTime @default(now())
  completedAt   DateTime?
  status        String   @default("enrolled") // enrolled, completed, dropped
  progress      Float    @default(0) // 0-100

  user          User     @relation(fields: [userId], references: [id])
  cohort        Cohort?  @relation(fields: [cohortId], references: [id])

  @@unique([userId, courseCode, cohortId])
}

// === EVENTS & MEETUPS ===

model Event {
  id            String   @id @default(cuid())
  title         String
  kind          String   // weekly, monthly, masterclass, showcase, one-off
  description   String
  hostId        String?
  hostName      String?  // denormalized for display
  status        String   @default("upcoming") // upcoming, live, completed, cancelled
  isRecurring   Boolean  @default(false)
  recurrence    String?  // "weekly-tue", "monthly-first-fri"
  dayOfWeek     String?  // TUE, FRI, SAT
  time          String?  // "02:00", "19:00", "15:00"
  timezone      String   @default("CET")
  startDate     DateTime
  endDate       DateTime?
  replayUrl     String?
  viewCount     Int      @default(0)
  maxAttendees  Int?
  discordChannelId String?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  host          User?    @relation("EventHost", fields: [hostId], references: [id])
  attendees     EventAttendee[]
  ships         Ship[]

  @@index([status])
  @@index([startDate])
}

model EventAttendee {
  id            String   @id @default(cuid())
  eventId       String
  userId        String
  attendedAt    DateTime?
  role          String   @default("attendee") // attendee, host, moderator

  event         Event    @relation(fields: [eventId], references: [id])
  user          User     @relation(fields: [userId], references: [id])

  @@unique([eventId, userId])
}

// === SHIPS ===

model Ship {
  id            String   @id @default(cuid())
  builderId     String
  builderName   String   // denormalized for display
  project       String
  projectUrl    String?  // GitHub URL
  commit        String   // git commit hash
  branch        String   // main, feat/swarm, dev, release, exp
  buildTimeMin  Int      // minutes
  loc           Int      // lines of code added
  agentCount    Int      @default(1)
  stack         String   // claude, cursor, opencode, jido+mcp
  category      String   // skills, workflows, mcp, workspaces, apps
  description   String?
  status        String   @default("shipped") // building, shipped, archived
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  builder       User     @relation(fields: [builderId], references: [id])
  courseCode    String?
  course        Course?  @relation(fields: [courseCode], references: [id])
  eventId       String?
  event         Event?   @relation(fields: [eventId], references: [id])

  @@index([builderId])
  @@index([project])
  @@index([category])
  @@index([createdAt])
  @@index([stack])
}

// === AGENTS ===

model Agent {
  id            String   @id @default(cuid())
  name          String
  type          String   // assistant, orchestrator, evaluator, reviewer
  status        String   @default("active") // active, idle, offline
  harness       String   // claude, cursor, opencode, jido
  mcpEnabled    Boolean  @default(false)
  currentTask   String?
  ships         Int      @default(0)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  @@index([status])
  @@index([harness])
}

// === WORKSPACES ===

model Workspace {
  id            String   @id @default(cuid())
  name          String
  userId        String?
  status        String   @default("active") // active, paused, expired
  plan          String   @default("free") // free, pro, team
  repoUrl       String?
  agents        Int      @default(0)
  mcpServers    Int      @default(0)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  @@index([status])
  @@index([userId])
}

// === DISCORD ===

model DiscordChannel {
  id            String   @id @default(cuid())
  discordId     String   @unique
  name          String
  type          String   // text, voice, category, thread
  description   String?
  memberCount   Int      @default(0)
  isPinned      Boolean  @default(false)
  lastMessageAt DateTime?
  syncedAt      DateTime @default(now())
}

model DiscordRole {
  id            String   @id @default(cuid())
  discordId     String   @unique
  name          String
  color         String?
  permissions   String[] @default([])
  memberCount   Int      @default(0)
  syncedAt      DateTime @default(now())
}

// === TESTIMONIALS ===

model Testimonial {
  id            String   @id @default(cuid())
  userId        String?
  author        String   // "@vee", "@rune", etc.
  role          String   // "skills · grad CRS-300"
  quote         String
  verified      Boolean  @default(false)
  courseId      String?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  @@index([verified])
}

// === SYSTEM STATUS ===

model SystemStatus {
  id            String   @id @default(cuid())
  key           String   @unique // agents_active, builds_shipped, avg_build_time, etc.
  value         String   // numeric or status string
  unit          String?  // "agents", "builds", "m", "percent"
  updatedAt     DateTime @default(now())
}

// === MILESTONES (for MoM velocity) ===

model Milestone {
  id            String   @id @default(cuid())
  metric        String   @unique // ships_this_week, active_builders, etc.
  value         Float
  period        String   // week, month
  periodStart   DateTime
  periodEnd     DateTime
  createdAt     DateTime @default(now())

  @@index([metric, periodStart])
}
```

---

## 3.2 API Routes Required

### 3.2.1 Hero & Community Metrics

| Route | Method | Returns | Used By |
|---|---|---|---|
| `/api/status` | GET | `{ agents: N, ships: N, workspaces: N, builders: N, avgBuild: N, seatsLeft: N }` | Hero, CommunityMetrics, Footer |
| `/api/status/health` | GET | `{ systems: "nominal", build: "0xa1f9c2", latency: 14 }` | Footer status strip |
| `/api/leaderboard` | GET | `{ top: [{ handle, shipped, loc, success, stack }], byStack: [{ name, pct }] }` | CommunityMetrics ticker, WallOfShipped side stats |

### 3.2.2 Meetups

| Route | Method | Returns | Used By |
|---|---|---|---|
| `/api/events` | GET | `{ upcoming: Event[], live: Event[], archive: Event[] }` | MeetupsContent, Homepage Meetups section |
| `/api/events/:id` | GET | Single event with host, attendees, replay | MeetupsContent detail |
| `/api/events/live` | GET | Currently live events | MeetupsContent live badge |
| `/api/channels` | GET | `{ channels: [{ name, description, members, pinned }] }` | MeetupsContent channels section |

### 3.2.3 Courses

| Route | Method | Returns | Used By |
|---|---|---|---|
| `/api/courses` | GET | `{ courses: Course[], stats: { graduates, totalLessons, curriculumHours, shipRate } }` | CoursesContent, Homepage Academy section |
| `/api/courses/:code` | GET | Single course with syllabus | CoursesContent detail |
| `/api/cohorts` | GET | `{ active: [{ code, start, seats, status }], all: Cohort[] }` | CoursesContent cohort calendar |
| `/api/testimonials` | GET | `{ quotes: [{ author, role, quote }] }` | CoursesContent graduates section |
| `/api/courses/stats` | GET | `{ graduates: N, lessons: N, hours: N, shipRate: N }` | CoursesContent stats strip |

### 3.2.4 Wall of Shipped

| Route | Method | Returns | Used By |
|---|---|---|---|
| `/api/ships` | GET | `{ ships: Ship[], total: N, stats: { avgBuild, agentsPerRun, today, velocity } }` | WallOfShipped, ShippedContent |
| `/api/ships/:id` | GET | Single ship detail | ShippedContent latest build |
| `/api/ships/stream` | SSE | Real-time ship events | WallOfShipped live feed |
| `/api/ships/stats` | GET | `{ allTime, thisWeek, medianBuild, successRate, velocity, activeBuilders }` | ShippedContent stats strip |
| `/api/ships/top` | GET | `{ shippers: [{ rank, handle, shipped, loc, success, tier }] }` | ShippedContent leaderboard |
| `/api/ships/categories` | GET | `{ categories: [{ name, count, projects }] }` | ShippedContent categories section |

### 3.2.5 Admin (internal)

| Route | Method | Returns | Used By |
|---|---|---|---|
| `/api/admin/seed` | POST | `{ seeded: N }` | One-time data seeding |
| `/api/admin/status` | POST | `{ updated: key }` | Update system status values |
| `/api/admin/events` | POST | `{ created: eventId }` | Create/manage events |
| `/api/admin/ships` | POST | `{ created: shipId }` | Log new ships |
| `/api/admin/courses` | POST | `{ updated: courseCode }` | Update course catalog |

---

## 4. Data Migration Phases

### Phase 1: Foundation (Week 1-2)

**Goal:** Database schema, API routes for core data, seed initial data.

- [ ] **1.1** Update `prisma/schema.prisma` with full schema (Section 3.1)
- [ ] **1.2** Set up PostgreSQL database (or keep SQLite for dev, migrate to Postgres for prod)
- [ ] **1.3** Run Prisma migrations: `npx prisma migrate dev`
- [ ] **1.4** Generate Prisma client: `npx prisma generate`
- [ ] **1.5** Create API route `/api/status` — hero metrics endpoint
- [ ] **1.6** Create API route `/api/status/health` — footer health check
- [ ] **1.7** Create API route `/api/leaderboard` — top builders + stack distribution
- [ ] **1.8** Seed initial data: users, agents, workspaces, system status
- [ ] **1.9** Update `hero.tsx` — replace `TICKER` and metric chips with API calls
- [ ] **1.10** Update `community-metrics.tsx` — replace `METRICS` and `TICKER_ITEMS` with API calls
- [ ] **1.11** Update `footer.tsx` — replace static status strip with API calls

### Phase 2: Meetups & Events (Week 2-3)

**Goal:** Event management, Discord channel sync, meetup pages live.

- [ ] **2.1** Create API route `/api/events` — event listing with filters
- [ ] **2.2** Create API route `/api/events/live` — currently live events
- [ ] **2.3** Create API route `/api/channels` — Discord channel sync
- [ ] **2.4** Build Discord bot integration (or use Discord API webhook) for channel sync
- [ ] **2.5** Update `meetups-content.tsx` — replace `EVENTS`, `ARCHIVE`, `CHANNELS`, `LEADERS` with API calls
- [ ] **2.6** Update `meetups.tsx` (homepage section) — same event data source
- [ ] **2.7** Build admin interface for event creation/management (or use Prisma Studio)
- [ ] **2.8** Seed initial events data from existing mock data

### Phase 3: Courses & Academy (Week 3-4)

**Goal:** Course catalog, cohort management, enrollment tracking.

- [ ] **3.1** Create API route `/api/courses` — full course catalog
- [ ] **3.2** Create API route `/api/courses/:code` — single course with syllabus
- [ ] **3.3** Create API route `/api/cohorts` — active cohort calendar
- [ ] **3.4** Create API route `/api/testimonials` — verified graduate quotes
- [ ] **3.5** Create API route `/api/courses/stats` — academy statistics
- [ ] **3.6** Update `courses-content.tsx` — replace all mock arrays with API calls
- [ ] **3.7** Update `academy.tsx` (homepage section) — replace `COURSES` with API calls
- [ ] **3.8** Build enrollment flow (integrate with Mautic/Activepieces)
- [ ] **3.9** Seed course data from existing mock data (add CRS-400)

### Phase 4: Wall of Shipped (Week 4-5)

**Goal:** Real ship feed, leaderboard, category filtering.

- [ ] **4.1** Create API route `/api/ships` — paginated ship feed
- [ ] **4.2** Create API route `/api/ships/stream` — SSE for real-time updates
- [ ] **4.3** Create API route `/api/ships/stats` — aggregated statistics
- [ ] **4.4** Create API route `/api/ships/top` — leaderboard
- [ ] **4.5** Create API route `/api/ships/categories` — category breakdown
- [ ] **4.6** Update `wall-of-shipped.tsx` — replace `mkShip()`, `BUILDERS`, `PROJECTS` with API calls
- [ ] **4.7** Update `shipped-content.tsx` — replace all mock data with API calls
- [ ] **4.8** Build GitHub integration for automatic ship detection (webhook)
- [ ] **4.9** Seed ship data from existing mock data

### Phase 5: Join CTA & Footer (Week 5)

**Goal:** Dynamic Join CTA, live footer status.

- [ ] **5.1** Update `footer.tsx` `JoinCta` — replace hardcoded "12 seats remaining" with cohort data
- [ ] **5.2** Update `footer.tsx` `JoinCta` metrics — replace hardcoded numbers with API calls
- [ ] **5.3** Update footer status strip — replace static "all systems nominal" with health check
- [ ] **5.4** Update footer build hash — read from `git rev-parse HEAD` at build time

### Phase 6: Integration & Polish (Week 5-6)

**Goal:** Marketing stack integration, real-time updates, performance.

- [ ] **6.1** Integrate Discord bot for real-time event updates and member sync
- [ ] **6.2** Integrate Mautic for course enrollment tracking
- [ ] **6.3** Integrate Activepieces for automated event notifications
- [ ] **6.4** Implement SSE for live ship feed (Phase 4.2)
- [ ] **6.5** Add caching headers to API routes (Redis or Next.js cache)
- [ ] **6.6** Add rate limiting to API routes
- [ ] **6.7** Add authentication to admin routes
- [ ] **6.8** Performance testing and optimization
- [ ] **6.9** Analytics integration (PostHog or Plausible)

---

## 5. Data Flow Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    DISCORD SERVER                        │
│  ┌───────────┐  ┌───────────┐  ┌───────────────────┐   │
│  │ Bot (sync) │  │ Webhooks  │  │ Member events     │   │
│  └─────┬─────┘  └─────┬─────┘  └────────┬──────────┘   │
│        │              │                  │              │
│        ▼              ▼                  ▼              │
│  ┌──────────────────────────────────────────────────┐  │
│  │              DATABASE (PostgreSQL)                │  │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐  │  │
│  │  │ User   │ │ Event  │ │ Ship   │ │ Course   │  │  │
│  │  │        │ │        │ │        │ │          │  │  │
│  │  │Discord │ │Attendee│ │Builder │ │Cohort    │  │  │
│  │  │Channel │ │        │ │Project │ │Enroll    │  │  │
│  │  └────────┘ └────────┘ └────────┘ └──────────┘  │  │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐  │  │
│  │  │Agent  │ │Work-   │ │Testi-  │ │System   │  │  │
│  │  │       │ │space   │ │monial  │ │Status   │  │  │
│  │  └────────┘ └────────┘ └────────┘ └──────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  Mautic         │ │  Activepieces   │ │  GitHub         │
│  (enrollment)   │ │  (notifications)│ │  (webhooks)     │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

---

## 6. Migration Checklist by Component

### 6.1 Components That Need Full Replacement

| Component | File | Mock Data | Real Data Source |
|---|---|---|---|
| Hero | `hero.tsx` | `TICKER`, metric chips | `/api/status` |
| Community Metrics | `community-metrics.tsx` | `METRICS`, `TICKER_ITEMS` | `/api/status`, `/api/leaderboard` |
| Meetups Content | `meetups-content.tsx` | `EVENTS`, `ARCHIVE`, `CHANNELS`, `LEADERS` | `/api/events`, `/api/channels` |
| Courses Content | `courses-content.tsx` | `COURSES`, `SYLLABUS`, `COHORT`, `QUOTES` | `/api/courses`, `/api/cohorts`, `/api/testimonials` |
| Wall of Shipped | `wall-of-shipped.tsx` | `mkShip()`, `BUILDERS`, `PROJECTS` | `/api/ships`, `/api/ships/stream` |
| Shipped Content | `shipped-content.tsx` | `mkShip()`, `BUILDERS`, `PROJECTS_BY_CATEGORY`, `STATS`, `TOP_SHIPPERS` | `/api/ships`, `/api/ships/top`, `/api/ships/categories` |
| Footer | `footer.tsx` | Static status strip | `/api/status/health` |
| Join CTA | `footer.tsx` | Hardcoded seats, metrics | `/api/cohorts`, `/api/status` |
| Academy (homepage) | `academy.tsx` | `COURSES` (3 items) | `/api/courses` |
| Meetups (homepage) | `meetups.tsx` | `EVENTS`, `ARCHIVE`, stats | `/api/events` |

### 6.2 Components That Stay Static (No Change)

| Component | File | Reason |
|---|---|---|
| Atoms | `atoms.tsx` | UI primitives |
| Sound Context | `sound-context.tsx` | Audio utility |
| Interactive Terminal | `interactive-terminal.tsx` | UI component |
| Copy Command | `copy-command.tsx` | UI utility |
| Theme Provider | `theme-provider.tsx` | Next-themes wrapper |
| Page Banner | `page-banner.tsx` | UI component |
| Header | `header.tsx` | Navigation |
| Principles | `principles.tsx` | Static marketing copy |
| The Loop | `the-loop.tsx` | Static marketing copy |
| Tools | `tools.tsx` | Static marketing copy |
| Factory Content | `factory-content.tsx` | Needs separate review |
| Software Factory Content | `software-factory-content.tsx` | Needs separate review |
| Way of Teams Content | `way-of-teams-content.tsx` | Needs separate review |
| Login Content | `login-content.tsx` | Auth flow |

---

## 7. Implementation Notes

### 7.1 API Route Pattern

All API routes should follow this pattern:

```typescript
// Example: src/app/api/status/route.ts
import { NextResponse } from "next/server";
import { db } from "@/lib/db";

export async function GET() {
  const [agentCount, shipCount, workspaceCount, userCount, cohorts] =
    await Promise.all([
      db.agent.count({ where: { status: "active" } }),
      db.ship.count(),
      db.workspace.count({ where: { status: "active" } }),
      db.user.count(),
      db.cohort.aggregate({
        where: { status: "open" },
        _sum: { enrolledSeats: true, maxSeats: true },
      }),
    ]);

  const avgBuild = await db.ship.aggregate({ _avg: { buildTimeMin: true } });

  return NextResponse.json({
    agents: agentCount,
    ships: shipCount,
    workspaces: workspaceCount,
    builders: userCount,
    avgBuild: Math.round(avgBuild._avg.buildTimeMin ?? 0),
    seatsLeft: cohorts._sum.maxSeats! - cohorts._sum.enrolledSeats!,
  });
}
```

### 7.2 Client-Side Data Fetching

Use `use` hook (React 19) or `fetch` with caching:

```typescript
// Example: hero.tsx
async function fetchStatus() {
  const res = await fetch("/api/status", {
    next: { revalidate: 30 }, // 30s cache
  });
  return res.json();
}

export function Hero() {
  const status = React.use(fetchStatus());
  // Use status.agents, status.ships, etc.
}
```

### 7.3 Real-Time Updates

For the ship feed, use Server-Sent Events:

```typescript
// src/app/api/ships/stream/route.ts
import { NextRequest, NextResponse } from "next/server";

export function GET(request: NextRequest) {
  const stream = new ReadableStream({
    async start(controller) {
      const send = (data: string) => {
        controller.enqueue(new TextEncoder().encode(`data: ${data}\n\n`));
      };

      // Send initial state
      const ships = await db.ship.findMany({
        orderBy: { createdAt: "desc" },
        take: 14,
      });
      send(JSON.stringify({ type: "init", ships }));

      // Listen for new ships via webhook or polling
      const interval = setInterval(async () => {
        const newShip = await db.ship.findFirst({
          orderBy: { createdAt: "desc" },
        });
        if (newShip) send(JSON.stringify({ type: "new", ship: newShip }));
      }, 5000);

      request.signal.addEventListener("abort", () => {
        clearInterval(interval);
        controller.close();
      });
    },
  });

  return new NextResponse(stream.body, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
    },
  });
}
```

### 7.4 Data Seeding

Create a seed script (`prisma/seed.ts`) to populate initial data from existing mock data:

```typescript
// prisma/seed.ts
import { PrismaClient } from "@prisma/client";
const db = new PrismaClient();

async function main() {
  // Seed users from mock builders
  const builders = [
    { handle: "@kira", name: "Kira", role: "builder" },
    { handle: "@neo", name: "Neo", role: "builder" },
    // ... etc
  ];

  for (const b of builders) {
    await db.user.upsert({
      where: { name: b.name },
      update: {},
      create: { ...b, email: `${b.name.toLowerCase()}@aigf.local` },
    });
  }

  // Seed courses from mock data
  await db.course.createMany({
    data: [
      {
        code: "CRS-100",
        title: "The 30-Min Feature Run",
        outcome: "Take a fuzzy feature request from idea to merged PR...",
        level: "LVL 100",
        // ... etc
      },
      // ... all courses
    ],
  });

  // Seed events
  await db.event.createMany({
    data: [
      {
        title: "The 2 AM Bug Fix",
        kind: "weekly",
        description: "Live screen-share office hours...",
        dayOfWeek: "TUE",
        time: "02:00",
        status: "upcoming",
        isRecurring: true,
        recurrence: "weekly-tue",
      },
      // ... all events
    ],
  });

  console.log("Seed complete");
}

main();
```

---

## 8. Dependencies & Infrastructure

### 8.1 New Dependencies

```bash
npm install @prisma/client
npm install -D prisma
npm install eventsource-parser  # For SSE client
npm install discord.js          # For Discord bot integration
```

### 8.2 Environment Variables

```bash
# Database
DATABASE_URL="postgresql://user:pass@localhost:5432/aigf"

# Discord
DISCORD_BOT_TOKEN="bot_token_here"
DISCORD_SERVER_ID="server_id_here"

# GitHub (for ship webhook)
GITHUB_TOKEN="github_token_here"
GITHUB_WEBHOOK_SECRET="webhook_secret_here"

# Mautic (for enrollment)
MAUTIC_SITE_ID="site_id"
MAUTIC_API_KEY="api_key"

# Activepieces (for automation)
ACTIVEPIECES_URL="http://localhost:8080"
ACTIVEPIECES_API_KEY="api_key"
```

### 8.3 Infrastructure Changes

| Current | New | Notes |
|---|---|---|
| SQLite | PostgreSQL (prod) | SQLite OK for dev |
| No bot | Discord.js bot | For channel sync, member events |
| No webhooks | GitHub webhook | For automatic ship detection |
| Manual data entry | Mautic API | For course enrollment tracking |
| Manual notifications | Activepieces | For event notifications |

---

## 9. Risk Assessment

| Risk | Impact | Mitigation |
|---|---|---|
| Discord API rate limits | Medium | Cache channel data, poll at reasonable intervals |
| GitHub webhook delivery failures | Medium | Retry logic, fallback to polling |
| Database migration downtime | High | Use zero-downtime migration patterns |
| SSE connection drops | Low | Client-side reconnection with exponential backoff |
| Mautic/Activepieces integration complexity | Medium | Start with manual data entry, automate later |
| Real data quality issues | Medium | Admin dashboard for data correction |

---

## 10. Success Criteria

- [ ] Zero mock data arrays remain in any component
- [ ] All hero metrics reflect real database values
- [ ] Meetup events are created/managed via database, not hardcoded
- [ ] Course catalog is queryable from database
- [ ] Ship feed shows real git commits
- [ ] Leaderboard reflects actual builder statistics
- [ ] Footer status strip shows live system health
- [ ] Join CTA shows real cohort seat counts
- [ ] All API routes have proper error handling
- [ ] Database schema supports all current and near-future use cases
- [ ] Admin interface exists for data management
- [ ] Discord bot syncs channels and members
- [ ] GitHub webhook detects new ships automatically

---

## 11. Estimated Effort

| Phase | Effort | Dependencies |
|---|---|---|
| Phase 1: Foundation | 3-4 days | None |
| Phase 2: Meetups | 3-4 days | Phase 1 |
| Phase 3: Courses | 3-4 days | Phase 1 |
| Phase 4: Wall of Shipped | 4-5 days | Phase 1 |
| Phase 5: Join CTA & Footer | 1-2 days | Phase 1, 3 |
| Phase 6: Integration & Polish | 3-4 days | All phases |
| **Total** | **~17-23 days** | |

---

## 12. Related Planning Documents

This plan covers the database and API migration. The following companion documents cover additional work:

| Document | Path | Covers |
|---|---|---|
| Courses & Meetups File Structure | `data/aigf-courses-meetups-file-structure.md` | One-file-per-course and one-file-per-meetup folder structure, file formats, admin workflow |
| GitHub & Google Login | `data/aigf-github-google-login-plan.md` | Supabase Auth integration, OAuth configuration, multi-tenant profile sync |
| AI Blog Posts in Dirrty Mixbag | `data/aigf-ai-blog-posts-in-community.md` | Blog content strategy, AI-assisted writing workflow, community engagement |
| Blog on AIGF Site | `data/aigf-blog-in-aigf-site.md` | AIGF blog pages, Dirrty Mixbag news integration, content flow |
| Blog Management Skill | `data/aigf-blog-management-skill.md` | Captain-facing skill for creating/editing/publishing blog posts from natural language |

## 13. Next Immediate Actions

1. **Captain approval** — Review and approve this plan and all companion documents
2. **Database decision** — SQLite (keep current) or PostgreSQL (recommended for prod)
3. **Dirrty Mixbag auth** — Enable GitHub and Google login in Supabase
4. **File structure** — Create `data/courses/` and `data/meetups/` directories
5. **Blog structure** — Create `data/blog/` directory structure
6. **Start Phase 1** — Schema, migrations, seed data, core API routes
