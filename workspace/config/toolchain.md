# Toolchain Registry

The validated engines Ymir adopts rather than rebuilds (AGENTS.md law 8 — open
source first). Ymir owns only the UI, the runtime, and A2A collaboration; everything
below wears a Norse name over a proven engine. Wrappers live in `bin/`; secrets come
from `.env.local` / `.env.realm`, never here.

```
toolchain[16]{domain,engine,norse,wrapper,auth_env}:
  "memory","engram/engdbram","Mimirsbrunn","bin/mimir.sh","MIMIRSBRUNN_URL"
  "memory bridge","Kaia engram bridge (:4602)","Mimirsbrunn","bin/mimir.sh","MIMIRSBRUNN_URL"
  "queue","Redis","Ratatoskr's nest","(a2a-bus)","REDIS_URL"
  "protocol","a2aproject/a2a","Ratatoskr","(a2a-bus)","—"
  "gateway","Traefik / Caddy","Bifrost","(deploy)","BIFROST_PORT"
  "auth","OAuth2-proxy / Authentik + JWS","Heimdall","(deploy)","HEIMDALL_OAUTH_CLIENT_ID"
  "tunnel","cloudflared","Gjallarhorn","(deploy)","CLOUDFLARE_TUNNEL_TOKEN"
  "sandbox","Docker (rootless)","Utgard","bin/utgard.sh","—"
  "files","MinIO / FileBrowser","Skrymir","(deploy)","—"
  "process supervisor","PM2 / Docker","Valhalla","(valhalla)","—"
  "SCM","git + gh CLI","Yggdrasil","bin/yggdrasil.sh","GITHUB_TOKEN"
  "local models","llama-server / LM Studio","—","bin/bifrost-bridge.sh","LM_STUDIO_URL"
  "cloud models","opencode-go bridge","Bifrost bridge","bin/bifrost-bridge.sh","OPENCODE_GO_API_KEY"
  "harnesses","OpenCode / Pi / Claude / Codex / Cursor","Hamr","bin/hamr-harness.sh","—"
  "backlog","tasks-axi","Nornir","(.agents/config/cron.yaml)","—"
  "library of the halls","command-factory / firstmate (upstream) / .compliance","—","—","—"
```

## Auth status

```
auth[6]{engine,env,checked}:
  "opencode-go bridge","OPENCODE_GO_API_KEY (in .env.local)","bin/bifrost-bridge.sh --status"
  "GitHub","GITHUB_TOKEN","gh auth status"
  "LM Studio / llama-server","LM_STUDIO_URL","curl :8080/v1/models"
  "Redis","REDIS_URL","redis-cli ping"
  "engram bridge","MIMIRSBRUNN_URL (:4602)","bin/mimir.sh health"
  "Docker","(socket)","docker info"
```

## Rules

- Before synthesizing a feature, ask: *does a validated engine already do this?*
  If yes, adopt it and Norse-name the wrapper; do not rebuild.
- One wrapper per domain in `bin/`; it is the only interface agents use.
- Secrets only from env; the registry names the variable, never the value.
- Never claim a tool is present without a `--status` check.

## Maintaining this

- **Owner:** Brokk. Add a row when an engine is adopted; update its `auth` row when
  the check path changes.
