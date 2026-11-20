# ymir-gateway — P1

Plan 68, phase 1: **one surface the phone and the computer both speak**, so that "the phone can do
what Brokk can do" is a first milestone rather than a promise.

## What is ours, and what is adopted

| piece | | why |
|---|---|---|
| `session.mjs` | **ours** | session identity across devices — nobody else's concept |
| `acp.mjs` | **ours, on an adopted SDK** | the brain seam, so voice never branches on hosted vs local |
| ACP protocol | **adopted** | `@agentclientprotocol/sdk` 1.7.0, Apache-2.0 (Zed Industries) |
| WebRTC voice sessions | **adopted** | `@livekit/agents` 1.9.1, Apache-2.0, self-hosted |
| local voice loop | **adopted by reference** | plan 34's design; `vui` (Apache-2.0) as the working example |

## The confirmed ACP surface (verified against the installed 1.7.0, not guessed)

```
SessionBuilder
  .withAgentCapabilities({ loadSession })
  .withMcpServer(mcpServer)              ← the house's DOORS, as standard MCP
  .withAdditionalDirectories(paths)
  .start(): Promise<ActiveSession>

ActiveSession
  .prompt(prompt: string | ContentBlock | ContentBlock[])
  .nextUpdate()          streaming updates
  .readText()            the assembled reply
  .dispose()
```

**`withMcpServer` is the answer to the door surface.** The agent is handed the house's MCP servers
exactly the way any other ACP client would — so there is **no custom tool bridge and no duplicated
door**. `ymir-mcp-gateway` and the existing MCP servers are referenced, never reimplemented, which is
what keeps the one-capability-one-door law true as we add a second caller.

## Local models

`AGENTS.md` decides it: **local → `pi`, hosted → `opencode`.** The gateway never picks a model — it
picks a *brain*, and the brain's config picks the model. `chooseBrain()` prefers the local rail when
it answers. `pi.mjs` (local, over the llama rail) is the second implementation of the same `Brain`
shape; it is the next file.

## Run the tests

```bash
node tools/ymir-gateway/session.test.mjs     # 12 checks, no network, no agent needed
```

## What is NOT done, and will not be pretended

- **No live ACP session has been opened yet.** The SDK surface is confirmed from its own types; the
  first real `start()` against `opencode acp` is the next job, and until that runs the seam is
  unexercised.
- **No MCP server list is configured.** `YMIR_MCP_SERVERS` is read but empty; P1 wires the house's
  servers in.
- **No voice, no phone client, no LiveKit.** Those are P2–P6 and each has its own acceptance test.

That last paragraph is the whole point of this file: a seam that *looks* right and was never called
is precisely what the rest of this project's history is made of.