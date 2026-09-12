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