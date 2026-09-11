# GitHub & Google Login Integration Plan

**Status:** Planning  
**Last updated:** 2025-10-01  
**Projects:** AIGeeks & Freaks, Dirty Mox Bag Community

---

## 1. Goal

Enable users to log in to both AIGeeks & Freaks and the Dirty Mox Bag community using GitHub or Google accounts. This leverages the existing Supabase Auth infrastructure in the Dirty Mox Bag community and extends it to support AIGeeks & Freaks as a second tenant.

---

## 2. Current State

### 2.1 Dirty Mox Bag Community

- **Auth:** Supabase Auth (email/password only currently)
- **DB:** PostgreSQL via Supabase
- **Tables:** `community_profiles`, `community_topics`, `community_posts`, etc.
- **Tenant:** `dirrtymixbag`
- **RLS:** Row Level Security policies per tenant
- **Frontend:** Astro-based site at `/dirrtymixbag`

### 2.2 AIGeeks & Freaks

- **Auth:** None currently (login page exists but not functional)
- **DB:** Prisma with SQLite (local dev)
- **Schema:** `User`, `Post` models only
- **Frontend:** Next.js 16 site at `aigeeksnfreaks.zerwiz.org`

---

## 3. Recommended Approach

### 3.1 Single Auth Provider (Supabase)

Use Supabase Auth as the single authentication provider for both platforms. This means:

- One Supabase project handles auth for both tenants
- GitHub and Google OAuth providers configured in Supabase
- Users log in once and get profiles in both communities
- RLS policies enforce tenant isolation

### 3.2 Multi-Tenant Profile Model

Extend the existing `community_profiles` table to support multiple tenants:

- `tenant_slug` field already exists (currently defaults to `dirrtymixbag`)
- Add `aigf` as a second tenant slug
- Users get profiles in both tenants automatically on signup
- Each tenant has its own profile data (bio, avatar, preferences)

---

## 4. Implementation Phases

### Phase 1: Supabase OAuth Configuration

**Goal:** Enable GitHub and Google login in Supabase.

1. **GitHub OAuth App**
   - Create GitHub OAuth application
   - Get client ID and secret
   - Configure callback URL: `https://whynotproductions.netlify.app/dirrtymixbag/login/`
   - Store credentials in Supabase project settings

2. **Google OAuth App**
   - Create Google Cloud OAuth application
   - Get client ID and secret
   - Configure authorized redirect URI
   - Store credentials in Supabase project settings

3. **Supabase Provider Configuration**
   - Enable GitHub provider in Supabase dashboard
   - Enable Google provider in Supabase dashboard
   - Set provider URLs and scopes
   - Configure email template overrides

4. **Environment Variables**
   - Add `GITHUB_CLIENT_ID` and `GITHUB_SECRET` to Supabase
   - Add `GOOGLE_CLIENT_ID` and `GOOGLE_SECRET` to Supabase
   - Add to Netlify deploy settings
   - Add to local `.env` files

### Phase 2: Frontend Auth Integration

**Goal:** Add GitHub and Google login buttons to both platforms.

1. **Dirty Mox Bag Login Page**
   - Add GitHub login button
   - Add Google login button
   - Keep email/password login as fallback
   - Handle OAuth callback flow
   - Redirect to community home after login

2. **AIGeeks & Freaks Login Page**
   - Add GitHub login button
   - Add Google login button
   - Keep email/password login as fallback
   - Handle OAuth callback flow
   - Redirect to AIGF home after login

3. **Session Management**
   - Use Supabase client-side session management
   - Store session in localStorage
   - Auto-refresh sessions
   - Handle session expiry gracefully

### Phase 3: Multi-Tenant Profile Sync

**Goal:** Auto-create profiles in both tenants when users sign up.

1. **Supabase Trigger**
   - Extend `handle_new_user_profile()` function
   - Create profile in `dirrtymixbag` tenant
   - Create profile in `aigf` tenant
   - Link profiles by `auth.users.id`

2. **Profile Data Sharing**
   - Allow users to set shared display name and avatar
   - Allow tenant-specific bio and preferences
   - Sync gamer tag across tenants (optional)

3. **RLS Policy Updates**
   - Add `aigf` tenant to existing RLS policies
   - Ensure cross-tenant data isolation
   - Test policy enforcement

### Phase 4: AIGF-Specific Auth Features

**Goal:** Enable AIGF-specific auth flows.

1. **Ship Attribution**
   - Link GitHub commits to user profiles
   - Show builder reputation on AIGF pages
   - Enable community forum topics per course/meetup

2. **Course Enrollment**
   - Track enrollment via Supabase
   - Link to community profile
   - Enable progress tracking

3. **Meetup Attendance**
   - Track attendance via Supabase
   - Link to community profile
   - Enable replay access for attendees

---

## 5. Security Considerations

### 5.1 OAuth Security

- Use PKCE flow for all OAuth requests
- Validate state parameter to prevent CSRF
- Store client secrets server-side only
- Use HTTPS for all auth endpoints

### 5.2 Session Security

- Use Supabase JWT tokens for session management
- Set appropriate token expiry (7 days default)
- Implement token refresh on expiry
- Invalidate sessions on password change

### 5.3 RLS Security

- Enforce tenant isolation at database level
- Never trust client-side tenant claims
- Use Supabase row-level security policies
- Test policies with different user roles

### 5.4 Rate Limiting

- Implement login rate limits (10 attempts per hour)
- Implement signup rate limits (3 per hour)
- Implement password reset rate limits (5 per hour)
- Use Supabase built-in rate limiting where available

---

## 6. Migration Path

### Phase 1: Setup (Week 1)

- [ ] Create GitHub OAuth application
- [ ] Create Google OAuth application
- [ ] Configure Supabase providers
- [ ] Add environment variables
- [ ] Test OAuth flow in development

### Phase 2: Frontend (Week 2)

- [ ] Add login buttons to Dirty Mox Bag
- [ ] Add login buttons to AIGF
- [ ] Implement OAuth callback handling
- [ ] Test session management
- [ ] Test cross-tenant profile creation

### Phase 3: Integration (Week 3)

- [ ] Extend Supabase trigger for multi-tenant profiles
- [ ] Update RLS policies for `aigf` tenant
- [ ] Add ship attribution flow
- [ ] Add course enrollment tracking
- [ ] Add meetup attendance tracking

### Phase 4: Polish (Week 4)

- [ ] Add logout flow
- [ ] Add profile management for both tenants
- [ ] Add session expiry handling
- [ ] Add error states for auth failures
- [ ] Performance testing and optimization

---

## 7. Success Criteria

- [ ] Users can log in with GitHub on both platforms
- [ ] Users can log in with Google on both platforms
- [ ] Users get profiles in both communities automatically
- [ ] Session persists across page reloads
- [ ] Logout works correctly
- [ ] RLS enforces tenant isolation
- [ ] Rate limiting prevents abuse
- [ ] OAuth flow works in production

---

## 8. Dependencies

- GitHub Developer account (for OAuth app)
- Google Cloud account (for OAuth app)
- Supabase project access (for provider configuration)
- Netlify access (for environment variables)
- AIGF codebase access (for login page updates)
- Dirty Mox Bag codebase access (for login page updates)

---

## 9. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| GitHub OAuth app rejection | Medium | Use personal account initially, migrate later |
| Google OAuth app verification delay | High | Use test users initially, request verification early |
| RLS policy bugs | High | Test thoroughly with different user roles |
| Session hijacking | High | Use HTTPS, secure cookies, regular token refresh |
| Rate limit bypass | Medium | Implement server-side rate limiting |
| Cross-tenant data leak | Critical | Test RLS policies, use Supabase audit logs |
