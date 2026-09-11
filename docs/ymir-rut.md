# YMIR RUT — System Specification v2.6

> **Status:** ADOPTED AS THE **TARGET** ARCHITECTURE (ENTRY 2026-09-11-009/010).
> The v2.6 spec below is the long-term zenith (Rust, NATS, Envoy, PostgreSQL,
> libgit2, Cgroups v2). The **current** implementation deliberately uses the
> agent-proficient stack — **TypeScript + Python + React + Vue** — with a
> one-for-one crumb trail to Rut so the eventual port is a *re-floor*, not a
> redesign. See the **Reconciliation** appendix at the end of this document.

---

# PART 1 — System Structure & Repository Layout Specification

## Monorepo & Daemon Module Architecture v2.6

### 1. Monorepo Workspace Topology

`Ymir Rut` is structured as an enterprise-grade Cargo workspace combined with isolated worker runtimes, ensuring clean boundaries between control plane daemons, tenant sandboxes, and agent harnesses. *(Today: an npm/pnpm workspace + Python services holding the same boundaries.)*

```
ymir-rut/
├── Cargo.toml                    # Workspace manifest (Rust Edition 2024)   → [today: package.json / pyproject.toml]
├── proto/                        # Shared Protocol Buffers & gRPC definitions → [today: JSON-RPC/.agents/bus schemas]
├── crates/
│   ├── bifrost/                  # [Ingress Gateway] Envoy/Reverse Proxy & TLS → [today: TS gateway service]
│   ├── hlidskjalf/               # [Control Plane] Telemetry, auth & dashboards → [today: React/Vue portal]
│   ├── svartalfaheim/            # [Tenant Realms] Namespace & credential stores → [today: TS tenant daemon]
│   ├── ratatoskr/                # [Event Bus] NATS JetStream broker integration → [today: TS A2A backbone + Redis]
│   └── yggdrasil/                # [Worktree Manager] libgit2 .treehouses engine → [today: TS worktree manager]
├── runtime/
│   ├── utgard/                   # [Sandboxes] Rootless Docker & cgroups v2 configs → [today: Python/Docker sandbox]
│   └── brokk/                    # [Worker Cluster] Autonomous agent harness → [today: Python/TS agent harness]
└── configs/                      # Cluster deployment helm charts & compose files → [today: docker-compose.yml]
```

### 2. Core Workspace Crates & Daemons

**A. Bifrost (`crates/bifrost/`)**

Role: Edge ingress gateway handling TLS termination, rate-limiting, and tenant route redirection.

Key Modules:
- `ingress::proxy`: Reverse proxy request forwarder.
- `auth::verifier`: Zero-trust token validation against Svartalfaheim stores.

**B. Hlidskjalf (`crates/hlidskjalf/`)**

Role: Central observability and dashboard metrics collector.

Key Modules:
- `telemetry::emitter`: Broadcasts operational metrics (98.4% traceability index tracking).
- `dashboard::api`: REST and GraphQL endpoints for cluster monitoring.

**C. Svartalfaheim (`crates/svartalfaheim/`)**

Role: Multi-tenant realm isolation engine.

Key Modules:
- `realm::namespace`: Ephemeral memory and environment variable scoping per tenant ID.
- `vault::keys`: Secure credential store with zero memory bleed guarantees.

**D. Ratatoskr (`crates/ratatoskr/`)**

Role: Asynchronous event bus and message broker.

Key Modules:
- `bus::nats`: JetStream publisher/subscriber client wrapper.
- `dispatch::router`: Inter-daemon event dispatch and trace logging.

**E. Yggdrasil (`crates/yggdrasil/`)**

Role: Parallel Git worktree manager (.treehouses).

Key Modules:
- `worktree::libgit2`: Manages isolated concurrent branches for agent code mutations without collision.
- `snapshot::diff`: Rapid staging and commit verification.

### 3. Worker & Runtime Subsystems

**A. Utgard (`runtime/utgard/`)**

Role: Ephemeral sandbox container runtime.

Specification: Configures rootless Docker engines, enforces Cgroups v2 limits (128GB memory ceiling), and applies strict seccomp syscall filters.

**B. Brokk (`runtime/brokk/`)**

Role: Autonomous agent execution worker cluster.

Specification: Python 3.12+ and Node.js 22 runtimes providing tool execution loops, prompt pipelines, and structured code transformation harnesses. *(This crate is the one Rut spec that is already current-stack — Python 3.12+ and Node/TypeScript.)*

### 4. Inter-Module IPC & Protocol Definitions

All inter-daemon communication relies on strongly typed Protocol Buffers (`proto/v2/`) compiled via tonic (gRPC) and JSON-RPC over Unix domain sockets for zero-latency local worker communication. *(Today: JSON-RPC 2.0 / A2A 1.0 over HTTP(S) + Unix-domain sockets between local daemons.)*

---

# PART 2 — Technical Architecture & Stack Requirements

## System Specification v2.6

### 1. System Topology & Component Architecture

`Ymir Rut` is structured around a decoupled, micro-daemon architecture designed for high-concurrency agent orchestration, zero-trust tenant isolation, and immutable worktree management.

```
                  ┌─────────────────────────────────────────┐
                  │          BIFROST (Ingress GW)           │
                  │  Envoy / NGINX Reverse Proxy & TLS Term │
                  └────────────────────┬────────────────────┘
                                       │
                  ┌────────────────────┴────────────────────┐
                  │       HLIDSKJALF (Control Plane)        │
                  │  Telemetry, Dashboards & Auth Daemons   │
                  └────────────────────┬────────────────────┘
                                       │
            ┌──────────────────────────┴──────────────────────────┐
            ▼                                                     ▼
┌───────────────────────────────────┐                 ┌───────────────────────────────────┐
│     SVARTALFAHEIM (Tenant A)      │                 │     SVARTALFAHEIM (Tenant B)      │
│  Isolated Namespace & Cred Store  │                 │  Isolated Namespace & Cred Store  │
└───────────┬───────────────────────┘                 └───────────┬───────────────────────┘
            │                                                     │
            ├──► RATATOSKR (Async Event Bus / NATS Broker)        │
            ├──► YGGDRASIL (Git Worktree Manager / libgit2)       │
            └──► UTGARD (Docker Ephemeral Sandboxes)              │
                  └── BROKK (Autonomous Agent Worker Cluster)     │
```

### 2. Comprehensive Technology Stack Requirements

**A. Core Control Plane & Daemons**

- Language: Rust (Edition 2024) — Chosen for zero-cost abstractions, memory safety without garbage collection, and lightning-fast async performance. *(Target. Today: TypeScript on Node.)*
- Async Runtime: Tokio — Handles concurrent I/O across thousands of active tenant connections and agent worker streams. *(Today: Node async I/O.)*
- API & IPC Layer: gRPC (Protobuf v3) and JSON-RPC for low-latency inter-daemon communication between Bifrost, Ratatoskr, and Brokk. *(Today: JSON-RPC 2.0 + A2A 1.0 + Redis.)*

**B. Agent Orchestration & Worker Runtime**

- Primary Agent Harness: Python 3.12+ / TypeScript (Node.js 22) — Supporting flexible LLM SDK bindings, tool execution loops, and structured planning pipelines. ✅ *already current stack*
- Worker Daemons (Brokk): Containerized worker nodes compiled as standalone static binaries interacting via IPC with the host kernel. *(Today: Python/TS services under PM2/Docker.)*

**C. Sandbox & Container Runtime (Utgard)**

- Isolation Engine: Docker Engine / containerd with rootless container configurations and seccomp syscall filtering.
- Resource Limits: Cgroups v2 enforcement per sandbox instance (default allocation: 128GB memory ceiling, ephemeral storage bounds).
- Network Policies: Strict zero-egress or scoped proxy-routed egress via Bifrost.

**D. Event Bus & Messaging (Ratatoskr)**

- Broker: NATS Server (JetStream enabled) — Ultra-low latency pub/sub messaging broker ensuring reliable event delivery across all seven system realms with 98.4% traceability index assurance. *(Today: Redis pub/sub under the A2A 1.0 task model.)*

**E. Version Control & Worktrees (Yggdrasil)**

- Engine: libgit2 / Git CLI — Manages isolated parallel branch worktrees (.treehouses) on shared storage volumes, preventing file collision during concurrent agent file mutations.

**F. Persistence & Storage Tier**

- Relational Database: PostgreSQL 16+ — Stores tenant metadata, user credentials, access control lists, and immutable audit logs. *(Today: Postgres available self-hosted; engram/SQLite stays the memory well.)*
- Object Storage: MinIO / AWS S3 Compatible — Caches build artifacts, large model contexts, and compressed snapshot archives for ephemeral sandboxes.

### 3. Security & Multi-Tenant Isolation Specifications

- **Realm Boundary Enforcement:** Svartalfaheim enforces strict namespace isolation. Memory pages, environment variables, and temporary credential tokens cannot cross tenant boundaries.
- **Traceability Auditing:** Every agent modification generates cryptographic checksums and execution telemetry logs recorded to the immutable audit ledger, maintaining a minimum traceability index of 98.4%.
- **Ephemeral Lifecycle:** Utgard sandboxes are destroyed immediately upon task completion or failure, wiping all local container states from disk.

---

# PART 3 — Multi-Tenant Agent OS

## Comprehensive Design & Architecture Specification (v2.6)

### 1. Executive Summary & Brand Identity

`Ymir Rut` is an advanced **Multi-Tenant Agent Operating System** designed for orchestrating autonomous AI worker clusters, secure tenant sandboxes, and immutable version-controlled worktrees. The brand identity fuses Norse mythic durability (symbolizing primeval creation, forged iron, and runic permanence) with modern cloud-native systems architecture (zero-trust isolation, ephemeral container runtimes, and real-time telemetry).

### 2. Design System Rules & Visual Language

**A. Typography**

- **Headings & Runes:** Cinzel (Google Fonts) — Provides carved, lapidary, monumental elegance representing ancient galdrastafir and runic inscriptions.
- **Code, Telemetry & Status:** JetBrains Mono (Google Fonts) — Precision monospaced typeface for command-line interfaces, json configs, and operational metrics.
- **Body & UI Text:** Inter (Google Fonts) — Clean, highly legible sans-serif for dashboard readability and interface descriptions.

**B. Color Palette & Lighting**

- **Canvas Base:** Deep obsidian slate (`#080c14` to `#060911`), evoking subterranean forge chambers and deep space telemetry.
- **Luminescence & Primary Accent:** Electric Cyan (`#38bdf8`, `#0ea5e9`), representing crystalline energy and Bifrost transit beams.
- **Secondary Accent:** Deep Violet / Indigo (`#818cf8`, `#6366f1`), denoting ethereal multi-tenant realms and deep compute nodes.
- **Borders & Structural Lines:** Muted slate (`#1e293b`, `#334155`), providing crisp container framing without visual clutter.

**C. Iconography & Emblem Geometry**

- **The Ymir Root Mark:** Combines the **Algiz** rune (signifying divine protection and branching worker stems) with a heavy **blacksmith anvil base** (signifying industrial strength and compute execution).
- **Chiseled Bevels:** Modeled with dual-layer vector depth — a dark iron forged exterior (`#334155`) paired with a luminous cyan chiseled inner edge (`#7dd3fc`).

### 3. Core Architecture Topology (The 7 Realms / Modules)

The Ymir OS runtime is structured around seven interlinked daemons and architectural modules:

| Realm | Module | Function |
|---|---|---|
| **Bifrost** | Ingress Gateway | Reverse proxy router and TLS HTTP gateway handling secure ingress traffic across tenant realms. Route spec: `/ingress/proxy/router` |
| **Hlidskjalf** | Control Plane & Observability | Centralized user dashboard providing real-time telemetry, trace logs, and cluster health metrics |
| **Svartalfaheim** | Tenant Isolation Realms | Scoped customer workspaces ensuring zero credential, memory, or state bleed between execution nodes. Isolation level: `sandbox_isolated` |
| **Brokk** | Autonomous Agent Workers | Primary task execution workers responsible for orchestrating builds, audits, and code transformations |
| **Utgard** | Ephemeral Sandboxes | Hardened Docker task runtimes for executing untrusted shell code and automated compilation safely. Runtime spec: `docker_ephemeral` |
| **Yggdrasil** | Git Worktree Manager | Manages isolated branch worktrees (.treehouses) for concurrent agent modifications without repo collision |
| **Ratatoskr** | Event Bus | Lightweight asynchronous message broker facilitating inter-daemon communication and event dispatch |

### 4. System Metadata & Config Specification

Every Ymir cluster broadcasts standardized telemetry conformant with the core engine spec:

```json
{
  "system_identifier": "ymir_rut_core",
  "operational_status": "NOMINAL",
  "core_light_wavelength": ["460nm (Cyan)", "390nm (Violet)"],
  "surface_texture": "Hand_Hammered_Steel",
  "crystalline_grid": "Icosahedral_Facets",
  "glyph_set": "A-Z_Runes_Simplified",
  "resource_allocation": {
    "engine": "utgard_sandbox",
    "instance": "78c70",
    "memory": "128GB"
  },
  "traceability_index": 0.984
}
```

### 5. Interactive Harness & CLI Specifications

- **Command Set:** Supports interactive commands such as `ymir status`, `brokk agent spawn`, and `ymir init`.
- **Traceability Assurance:** Every agent execution returns a verified traceability index (e.g., 98.4%), ensuring complete auditability of automated code changes.

---
---

# APPENDIX — Reconciliation: Rut (target) → Current Stack (today)

Both stacks speak the same Norse module language; only the floors differ.

| Rut module (target) | Current implementation (TypeScript · Python · React · Vue) |
|---|---|
| `crates/bifrost` (Envoy/gRPC) | TS gateway service — Traefik/Caddy + JSON-RPC routing; `auth::verifier` → Heimdall OAuth2-proxy |
| `crates/hlidskjalf` (Rust dashboard) | **React/Vue** portal — smidja visualizer paradigm, `#/memory`, `#/fleet`, `#/tasks`, Runes stream |
| `crates/svartalfaheim` (tenant/cred vault) | TS tenant daemon — realm namespaces, `.env.realm`, scoped registries, per-realm A2A discovery |
| `crates/ratatoskr` (NATS JetStream) | TS **A2A 1.0 backbone** + Redis queue under the task model (plan 25) |
| `crates/yggdrasil` (libgit2 .treehouses) | TS worktree manager over git CLI — `.yggdrasil/<agent-id>/` branches |
| `runtime/utgard` (rootless Docker, cgroups v2, seccomp) | Python/Docker sandbox — network-none, CPU/RAM/timeouts (unchanged intent) |
| `runtime/brokk` (agent harness, Py 3.12+/Node 22) | **already current stack** — Python + TS/Node agent harnesses, tool loops, mirroring |
| `proto/` (Protobuf/gRPC) | `.agents/bus` schemas (JSON-RPC 2.0, A2A task lifecycle, `InterAgentMessage`) |
| PostgreSQL 16 + MinIO | self-hosted Postgres 16 for tenant metadata/audit; MinIO/S3 for artifacts; **engram** = memory well |
| CLI (`ymir status`, `brokk agent spawn`, `ymir init`) | same command surface, implemented in TS/Python |
| Traceability index 98.4% | every significant action → Runes ledger + Mimirsbrunn episode (audit coverage) |

**Port policy (ENTRY-009/010):** ship end-to-end on TS/Python/React/Vue first; when stable,
re-floor each service into its Rut crate without redesigning the module contract.