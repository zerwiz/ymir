# The projector refuses a base that is not Plane

**Date:** 2026-11-19 · **Component:** Gimlé's projector (`bin/gimle/project.py`) · **Rules:** 07, 25, 27
**Plan:** 324 F6

## The fault

`project.py --plane` read `PLANE_API` with the default `http://127.0.0.1:8099`. On the Allfather's own machine **that
port is a `llama-server`** — measured with `ss -tlnp`: `0.0.0.0:8099 users:(("llama-server",…))`. So a token set without
repointing the base would have posted a project's cards **at a model server**: no error a person would notice, and a
board that never appears.

## What changed

- **No default.** `PLANE_API` is required; unset is a refusal that says why ("a base that does not answer as Plane would
  take the cards somewhere else").
- **The base is proved, not assumed.** `probe_plane()` asks `GET <base>/api/v1/workspaces/` with the token. Only an
  answer that looks like Plane passes; anything else is refused **with the reply quoted**, so the operator sees what
  actually answered.
- **The refusal happens before any write.** `--dry-run` and a real run take the same gate.

## Proof

```
python3 bin/gimle/project.py --home $YMIR_HOME --out /tmp/gp --plane --plane-project x --dry-run
  → project: --plane needs PLANE_API (no default …); cards skipped

PLANE_API=http://127.0.0.1:8099 PLANE_TOKEN=x python3 bin/gimle/project.py … --plane --dry-run
  → project: REFUSED — http://127.0.0.1:8099 does not answer as Plane
      (HTTP 401: {"error":{"message":"Invalid API Key","type":"authentication_error","code":401}}); nothing was posted
```

That reply is the llama-server's own authentication error, quoted — which is exactly the evidence a wrong base should
leave behind.

## What is not done

The working Plane base and token are not in the vault yet (plan 324 F5). Until they are, `--plane` is a named refusal
rather than a silent skip — which is the point of both.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #828
