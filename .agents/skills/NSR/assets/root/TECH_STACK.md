# Tech Stack — __PROJECT__

Authoritative stack-to-feature mapping. One primary stack per feature; pin versions.

## Stack Registry

| Layer | Technology | Version | Used For |
|-------|-----------|---------|----------|
| Language | *(fill)* | | |
| Backend framework | *(fill)* | | |
| Frontend framework | *(fill)* | | |
| Database | *(fill)* | | |
| Cache | *(fill)* | | |
| Auth | *(fill)* | | |
| Container | Docker | 24.x | Runtime, CI |
| Observability | *(fill)* | | |

## Feature → Stack Mapping

| Feature | Stack | Constraints |
|---------|-------|-------------|
| *(feature)* | *(stack)* | *(constraints)* |

## Rules

- Pin versions; no floating/latest in production.
- No new stack without updating this file AND `FEATURES.md`.
- Stacks must run on Mac/Linux/Windows (or be containerized).