# clients/

Per-client deployments. Each client is a first-class deployment target.

## Layout

```
clients/<client>/
├── README.md
├── staging.env.example
└── production.env.example
```

## Rules
- Client identity is an env input, never hardcoded.
- Commit templates only; inject real values/secrets at deploy.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
