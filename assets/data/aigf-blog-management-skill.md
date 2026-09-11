# Blog Management Skill for AIGeeks & Freaks

**Status:** Planning  
**Last updated:** 2025-10-01  
**Projects:** AIGeeks & Freaks, Dirrty Mixbag Community

---

## 1. Goal

Create a skill that allows the captain to manage blog posts from their regular workflow — creating, editing, and publishing blog posts without having to manually write files or navigate complex interfaces. The skill integrates with the captain's existing agent workflow (Claude Code, Cursor, OpenCode) and leverages the AI's natural language understanding to generate, review, and publish content.

---

## 2. Current State

### 2.1 Captain's Workflow

- Uses Claude Code, Cursor, OpenCode for agent engineering
- Creates code, reviews PRs, ships projects
- Communicates via Dirrty Mixbag community
- Manages courses and meetups

### 2.2 Current Blog State

- No blog exists yet
- All content is mock data
- No content management system
- No publishing workflow

---

## 3. Skill Design

### 3.1 Skill Name

`aigf-blog-manager`

### 3.2 Skill Location

```
firstmate/
└── .agents/skills/
    └── aigf-blog-manager/
        └── SKILL.md
```

### 3.3 Skill Capabilities

The skill provides these capabilities:

1. **Create Blog Post**
   - Captain describes topic in natural language
   - Skill generates outline from description
   - Captain approves or edits outline
   - Skill generates draft from approved outline
   - Captain reviews and approves draft
   - Skill publishes draft to AIGF blog and Dirrty Mixbag

2. **Edit Blog Post**
   - Captain describes changes in natural language
   - Skill finds relevant section in post
   - Captain approves changes
   - Skill edits post and republishes

3. **List Blog Posts**
   - Show recent posts
   - Filter by category, tag, date
   - Search by keyword

4. **Archive Blog Post**
   - Move post to archive
   - Update status
   - Notify community

5. **Schedule Blog Post**
   - Set future publish date
   - Skill publishes at scheduled time

### 3.4 Skill Commands

| Command | Description | Example |
|---|---|---|
| `/blog create` | Create new blog post | `/blog create "Prompt patterns for production agents"` |
| `/blog edit` | Edit existing post | `/blog edit "prompt-patterns-for-production-agents" "Add section on role-based prompts"` |
| `/blog list` | List blog posts | `/blog list --category agent-engineering` |
| `/blog archive` | Archive post | `/blog archive "old-post-slug"` |
| `/blog schedule` | Schedule post | `/blog schedule "draft-slug" --date 2025-10-15` |
| `/blog publish` | Publish scheduled post | `/blog publish "scheduled-slug"` |

---

## 4. Skill Workflow

### 4.1 Create Blog Post Workflow

```
1. Captain: /blog create "Prompt patterns for production agents"
2. Skill: Generate outline with key points
3. Captain: Approve or edit outline
4. Skill: Generate draft from approved outline
5. Captain: Review and approve draft
6. Skill: Publish to AIGF blog and Dirrty Mixbag
7. Skill: Notify community of new post
```

### 4.2 Edit Blog Post Workflow

```
1. Captain: /blog edit "post-slug" "Add section on role-based prompts"
2. Skill: Find relevant section in post
3. Skill: Generate edit suggestion
4. Captain: Approve or reject edit
5. Skill: Apply edit and republish
```

### 4.3 List Blog Posts Workflow

```
1. Captain: /blog list --category agent-engineering
2. Skill: Query blog files in category
3. Skill: Display list of posts with metadata
4. Captain: Select post for further action
```

---

## 5. Integration Points

### 5.1 AIGF Blog

- Read/write blog files in `data/blog/`
- Generate static pages from files
- Update blog index and category pages
- Add SEO metadata to pages

### 5.2 Dirrty Mixbag Community

- Create forum topics for new posts
- Update forum topics when posts are edited
- Link forum topics to blog posts
- Notify community of new posts

### 5.3 Marketing Stack

- Postiz: Schedule social media posts
- Mautic: Add subscribers to mailing list
- Activepieces: Automate cross-platform publishing

### 5.4 GitHub Integration

- Link blog posts to GitHub commits
- Attribute builder contributions
- Show builder reputation on posts

---

## 6. Skill File Format

### 6.1 Skill Metadata

```yaml
name: aigf-blog-manager
version: 1.0.0
description: Manage blog posts for AIGeeks & Freaks from your regular workflow
internal: true
trigger: /blog
```

### 6.2 Skill Instructions

The skill contains these instructions:

1. **Post Creation**
   - Parse captain's natural language request
   - Generate outline from request
   - Present outline for captain approval
   - Generate draft from approved outline
   - Present draft for captain approval
   - Publish to AIGF blog and Dirrty Mixbag

2. **Post Editing**
   - Parse captain's edit request
   - Find relevant section in post
   - Generate edit suggestion
   - Present suggestion for captain approval
   - Apply edit and republish

3. **Post Listing**
   - Query blog files
   - Filter by category, tag, date
   - Display list with metadata

4. **Post Archiving**
   - Move post to archive
   - Update status
   - Notify community

5. **Post Scheduling**
   - Set future publish date
   - Store scheduled post
   - Publish at scheduled time

---

## 7. Implementation Phases

### Phase 1: Skill Structure (Week 1)

- [ ] Create `aigf-blog-manager` skill directory
- [ ] Create SKILL.md with metadata and instructions
- [ ] Define skill commands and workflows
- [ ] Test skill loading in firstmate

### Phase 2: Post Creation (Week 2)

- [ ] Implement `/blog create` command
- [ ] Implement outline generation
- [ ] Implement draft generation
- [ ] Implement publishing to AIGF blog
- [ ] Implement publishing to Dirrty Mixbag

### Phase 3: Post Management (Week 3)

- [ ] Implement `/blog edit` command
- [ ] Implement `/blog list` command
- [ ] Implement `/blog archive` command
- [ ] Implement `/blog schedule` command
- [ ] Implement `/blog publish` command

### Phase 4: Integration (Week 4)

- [ ] Connect Postiz for social media
- [ ] Connect Mautic for email
- [ ] Connect Activepieces for automation
- [ ] Connect GitHub for builder attribution
- [ ] Test end-to-end workflow

---

## 8. Success Criteria

- [ ] Captain can create blog post with natural language
- [ ] Captain can edit blog post with natural language
- [ ] Captain can list blog posts with filters
- [ ] Captain can archive blog posts
- [ ] Captain can schedule blog posts
- [ ] Blog posts published to AIGF blog
- [ ] Blog posts published to Dirrty Mixbag
- [ ] Social media posts scheduled automatically
- [ ] Email notifications sent automatically
- [ ] Builder attribution linked to GitHub

---

## 9. Success Metrics

| Metric | Target | Measurement |
|---|---|---|
| Blog posts created via skill | 80%+ | Command usage count |
| Captain satisfaction | 4/5 | Captain feedback |
| Time to publish | <30 min | Time from command to publish |
| Error rate | <5% | Failed command count |
| Community engagement | 5+/comment | Comments per post |

---

## 10. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| AI-generated content quality | Medium | Human review of all drafts |
| Skill command errors | Low | Clear error messages + fallback |
| Publishing failures | Medium | Retry logic + error notifications |
| Content policy violations | Medium | Pre-publish review + automated checks |
| Low captain adoption | Medium | Simple commands + clear documentation |

---

## 11. Future Enhancements

### 11.1 AI-Assisted Writing

- Auto-generate outlines from course materials
- Auto-generate drafts from meetup recordings
- Auto-generate code examples from shipped projects
- Auto-generate community highlights from forum discussions

### 11.2 Community Contributions

- Allow community members to submit guest posts
- Auto-review guest post submissions
- Auto-approve guest posts from trusted members
- Auto-notify captains of new guest post submissions

### 11.3 Analytics Integration

- Track blog post views
- Track course enrollment from blog
- Track meetup attendance from blog
- Generate monthly content reports

### 11.4 Multi-Language Support

- Auto-translate blog posts to other languages
- Auto-detect reader language preference
- Auto-display posts in preferred language
