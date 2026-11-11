---
title: "{The system or part this page describes}"
status: "draft"             # draft | review | accepted | superseded | record
owner: "{Name}"
reviewer: "{Name}"
updated: "{YYYY-MM-DD}"
---

# {Title}

**Status:** {design | built}, {date}. This is an *explanation* page: it says how the system is shaped and why.

{Three sentences: what the system does, its main parts, and the one thing a reader must not get wrong.}

## Context: the system and what it talks to

{One sentence introducing the diagram.}

```mermaid
flowchart LR
    user([{Who uses it}]) -->|{what they do}| sys[{The system}]
    sys -->|{what it sends}| ext1[{An outside system}]
    ext2[{Another outside system}] -->|{what it sends}| sys
```

## Containers: the running parts and their wires

```mermaid
flowchart LR
    subgraph public[Public]
        web[Web app]
    end
    subgraph private[Private network]
        api[API]
        worker[Worker]
        db[(Database)]
    end
    web -->|HTTPS| api
    api -->|SQL| db
    api -->|jobs| worker
    worker -->|SQL| db
```

{Under the diagram, one short paragraph per part that needs explaining. Keep the diagram to about a dozen boxes.}

## How one request moves

```mermaid
sequenceDiagram
    actor P as Person
    participant A as API
    participant D as Database
    P->>A: {request}
    A->>D: {query}
    D-->>A: {rows}
    A-->>P: {answer}
```

## Decisions that shaped it

| Decision | Chosen | Why | Record |
|---|---|---|---|
| {question} | {answer} | {one line} | {link to the decision record} |

## What can go wrong

| Failure | How we notice | What happens |
|---|---|---|
| {failure} | {signal} | {behaviour} |

## References

- {Rules, plans, code paths, decision records.}

## CHANGE LOG

- **{YYYY-MM-DD}** — Written.
