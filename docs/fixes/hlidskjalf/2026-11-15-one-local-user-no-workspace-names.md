# Hlidskjalf: one local user, and no workspace names it did not read from the home

### Why

The operator found a **Workspace colours** panel on the Profile page, listing "Work · Owner", "Personal · Owner" and a
third row carrying a person's name. Plan 275 item 11 (one Hlidskjalf, no modes) was marked done, but the panel, the
per-workspace owner rows and a stored session's own workspace list survived it. The person's name was never in the
code: an older build's setup step added whatever name was typed as a workspace, and the stored session kept it.

### What was done

- **Profile:** the Workspace colours panel and its colour setters are gone; the page describes the seat, the company and
  the workspaces this home holds; the fake mailbox and the "via gate" line are replaced by the desktop session.
- **The workspace list is the registry's only.** `provisionWorkspace` no longer adds a typed name as a workspace, and a
  stored session's list is rebuilt from the realms on load, so an old row (like the person's name) is dropped.
- **No workspace label as a mode:** the search box says "Search the house…", the Fleet line no longer names a workspace,
  and the window title is the page and the app.
- **No login wording:** the Fleet's 401 note no longer says "Sign in"; there is no login.
- `src/hooks/useTenantDef.ts` had no caller left and is removed.

### Verified

`tsc --noEmit` clean, and no unused locals in the touched files. The worktree's build was served on a spare loopback port
and opened headless: Profile shows Personal and Company only; Fleet reads "7/31 agents standing · 1 working · A2A 1.0
cards published"; the search reads "Search the house…".

## CHANGE LOG

- 2026-11-15 — review-mend: added missing heading for #773
