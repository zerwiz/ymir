## install · unversioned · 2026-09-19 — no deploys: we have downloads, and one tunnel

### Why
- `deploy-staging.yml` fired on every push to main, failed every time (every run since
  2026-09-11), and published Hlidskjalf's `dist/` to Netlify — an SPA whose every panel
  calls a gate at 127.0.0.1, the operator's own machine. `deploy-production.yml` had never
  run. Both are removed.
- The Allfather, plainly: *"we don't have any deploy — we have downloads. The deploy we will
  have is me reaching the application in the future from my Cloudflare."* Distribution is
  npm; the only reach is the Gjallarhorn tunnel onto his own machine.
- A pipeline that fails silently on every merge and produces nothing anyone uses is the same
  fault as a mark counted from a log line: it looks like work and reports nothing true.

### Files
- `deploy-production.yml`
- `deploy-staging.yml`
