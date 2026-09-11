# Server Knowledge Crewmate Brief

## Task
Create a comprehensive operational knowledge base for the zerwizserver (100.88.238.83) — all services, tunnels, programs, and how to manage them.

## Model Host
- **Ollama** running on zerwizserver at `http://127.0.0.1:11434`
- **Model:** `qwen3.5:2b` (2.3B params, 262K context max — use 20K context for efficiency)
- **LM Studio** also available at `http://127.0.0.1:1234` (OpenAI-compatible API)

## Scope
- **Server:** zerwizserver (Tailscale IP 100.88.238.83, user `zerwizserver`, SSH key `~/.ssh/id_ed25519`)
- **Goal:** Document everything running on the server so any crewmate can manage services without asking the captain

## Research Areas

### 1. Cloudflare Tunnels
- List all cloudflared tunnel processes
- Read each config file in `/home/zerwizserver/.cloudflared/`
- Document what each tunnel exposes (URLs, ports, services)
- How to start/stop/restart each tunnel

### 2. Running Services & Processes
- Run `ps aux` to identify all non-system processes
- Map each process to its service (Anchor, WayOfTeams, CloudSync, WayOfCollab, Dojo, SearXNG, Forgejo, etc.)
- Document ports, protocols, and dependencies

### 3. Devbox Projects
- List all devbox project directories under `/home/zerwizserver/`
- For each project: what it is, how to start it, how to stop it
- Check for devbox config files (`.devbox.json`, `.cmd.sh`, etc.)

### 4. Docker Containers
- Check Docker container status
- Document what's running in containers (CloudSync, Temporal, etc.)

### 5. Web Applications
- investwayofteams (Vite preview on port 5179)
- wayofteams (Astro preview on port 4321)
- chat-server (port 9877)
- aigeeksandfreaks (Bun on port 3800)
- How to start/stop each

### 6. Databases
- PostgreSQL instances (anchor, wayofteams, cloudsync, wayofcollab, temporal)
- How to connect, start/stop

### 7. Utility Services
- CasaOS, LM Studio, CUPS, SSH, dnsmasq, etc.

## Output
Write to: `data/server-knowledge.md`

## Format
- Markdown with clear sections
- Tables for services (name, port, process, start command, stop command)
- Code blocks for commands
- Status indicators (currently running / not running / unknown)

## Constraints
- **Read-only investigation** — do NOT modify the server
- Use SSH commands to gather information
- Be thorough — document everything you find
- Include exact commands for starting, stopping, and restarting each service
- Note any services that are NOT managed by devbox or systemd
- Check if any services have systemd unit files
- Document the relationship between services (dependencies)
- Note which services are behind Cloudflare tunnels vs direct access
- Include the server access details (SSH, Tailscale IP, user)
- Check for any startup scripts or cron jobs
- Check for any environment variables or config files that affect services
- Check disk usage and any storage concerns
- Check for any backup mechanisms
