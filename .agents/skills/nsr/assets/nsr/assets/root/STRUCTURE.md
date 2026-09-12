# Structure — __PROJECT__

Repository tree map. Use this to navigate directly without unguided searching.

```
├── AGENTS.md                 # Root routing & core rules (fluff-free)
├── ARCHITECTURE.md           # High-level system overview
├── STRUCTURE.md              # This file — tree map
├── FEATURES.md               # Master feature registry
├── RULES.md                  # Execution rules index (detail in RULES/)
├── BEST_PRACTICES.md         # Design guidelines index (detail in docs/BEST_PRACTICES/)
├── CI_CD.md                  # Pipeline overview (detail in docs/CI_CD/)
├── TECH_STACK.md             # Stack-to-feature mapping
├── README.md                 # Product overview
│
├── RULES/                    # Execution & domain rules
├── docs/                     # Granular documentation
│   ├── BEST_PRACTICES/       # Engineering standards
│   ├── CI_CD/                # Pipeline configs + deployment/
│   │   └── deployment/       # envs/, clients/, tenants/, deploy.sh
│   ├── DEVELOPER_SETUP/      # Per-developer setup (consolidated + developers/)
│   ├── HOSTING/              # Per-hosting core info (consolidated + per-host)
│   ├── RUNBOOK/              # deployment.md, disaster-recovery.md, ops-tasks.md
│   ├── features/             # Per-feature deep-dive specs
│   └── research/             # Research sources
│
├── src/                      # Application source (add as needed)
├── tests/                    # Test suites (invoked via .agents/skills)
│
├── .agents/
│   └── skills/               # Scripted automation layer
│       ├── lifecycle/        # start.sh, stop.sh, status.sh, smoke_test.sh
│       ├── git_ops/          # create_branch.sh, safe_commit.sh, sync_upstream.sh
│       ├── features/         # <feature>/ (setup, test, smoke_test, rollback)
│       └── compliance/          # Embedded Agent Skill Compliance
│
└── .compliance/                 # Deterministic harness engine
    ├── config/               # core_four.yaml
    ├── gates/                # check_env.sh, check_paths.sh, check_platform.sh
    ├── harness/              # runner.py + envelopes/
    ├── telemetry/            # logger.py
    └── installer/            # install.sh
```

**Directory rule:** every functional subfolder must contain a local `AGENTS.md`.