# Huginn knows and raises his web tools

**Component:** fleet (plan 373, items 8 to 12)

## What was wrong

Firecrawl was removed in the 20 November container clean-up, and every search then failed with `ECONNREFUSED 127.0.0.1:3002`. Nothing in Ymir's MCP could say it was down, or raise it. The Firecrawl address was a literal in the seat writer. SearXNG had to be joined to the stack's network by hand, and that join is lost whenever SearXNG is recreated.

## What changed

- `bin/fleet/huginn-web.sh` is Huginn's door. `status` gives one row each for Firecrawl, SearXNG and the browser: up, down or missing, where, and road (local, borrowed or none). `up` raises the stack from its main checkout, retrying the cold start that races RabbitMQ's health check, joins SearXNG to the stack's network, waits for port 3002 and proves one search. `down` lowers the stack and keeps the volumes.
- The container law is enforced in `up`. It never raises a second copy, refuses a worktree or scratch path, refuses a stack whose override lacks `restart: unless-stopped` and the `ymir.owner` label, and does not build below 50 GiB free.
- Addresses come from configuration (`YMIR_FIRECRAWL_URL`, `YMIR_FIRECRAWL_BORROW_URL` and the rest, or `$YMIR_HOME/config/huginn.env`). The seat writer puts `YMIR_FIRECRAWL_URL` into the Firecrawl door. A seat with no stack and a borrow address reports `up` with road `borrowed`.
- The MCP tool `ymir_huginn` (`status`, `up`, `down`) serves it to every harness, and `ymir_research` now says `ymir_huginn up` when Firecrawl does not answer.
- Eir has a new `huginn` surface, red when a seat that owns the stack finds it down.

## Proof

`huginn-web.sh down` and then `up`, cold, took 93 seconds and ended with one search returning a result. `status` shows every tool up, local. A configured wrong address shows Firecrawl down, road none.
