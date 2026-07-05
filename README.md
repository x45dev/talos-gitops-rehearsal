# Ephemeral GitOps IDP (Local Edition)

A deterministic, high-speed ephemeral Kubernetes environment for local development.
It provisions production-identical Talos Linux clusters on a workstation using a "bootstrap-to-target" architecture, giving 1:1 pipeline parity with future cloud-based Cluster API (CAPI) deployments while keeping secrets zero-trust via YubiKey-backed SOPS/AGE.

See [docs/planning/PRD.md](docs/planning/PRD.md) for the full product requirements and [docs/planning/ZOR-ephemeral-gitops-idp-2026-07-05.md](docs/planning/ZOR-ephemeral-gitops-idp-2026-07-05.md) for the doubt-driven-development review of the approach.

## Architecture

The platform runs a dual-control-plane model:

1. **Management Plane (`kind`)** - a lightweight ephemeral cluster on the host workstation running the CAPI controllers.
2. **Target Plane (Talos Linux)** - the actual cluster, provisioned and managed by the Management Plane via CAPD (Cluster API Docker infrastructure provider).
3. **Bootstrap Security** - a `mise` task orchestrates hardware-backed secret decryption via YubiKey + SOPS/AGE, injecting the identity into the Management Plane.

## Project Structure

```text
.
├── .config/
│   ├── mise/          # Task orchestration and tool versioning (mise)
│   ├── sops/           # SOPS/AGE project secrets (age keypair, config)
│   ├── lefthook.yaml   # Git hooks (lint, secrets-leak guards, SOPS integrity check)
│   ├── vale/           # Prose linting (em dash, custom RKA rules)
│   ├── markdownlint/   # Markdown structural linting
│   └── cliff.toml      # git-cliff changelog generation config
├── docs/
│   └── planning/       # PRD and doubt-driven-development review for this project
└── docs/LICENSE
```

## Getting Started

### Prerequisites

- Docker
- [mise](https://mise.jdx.dev/)

### Development Tasks

```bash
mise run lint             # Run all linters (shfmt, shellcheck, hadolint, links, vale, markdownlint)
mise run hooks             # Sync Lefthook and run the pre-commit pipeline manually
mise run sops:project:manage   # Create/edit the encrypted project secrets file
mise run app:start         # Start the app via Docker Compose
```

The CAPD + Talos + Cilium spike test gates are defined under `test-capd-spike:*` (see `.config/mise/tasks/test-capd-talos.toml`); run `mise run test-capd-spike:all` to execute the full spike.

## Quality Standards

- **Automated Hooks**: Lefthook runs linting and SOPS/secrets-leak guards before every commit.
- **Zero Plaintext**: No decrypted credentials persist on local disk; secrets are SOPS/AGE-encrypted at rest.
- **Prose Linting**: vale and markdownlint enforce this project's documentation conventions (no em dashes, one sentence per line).
