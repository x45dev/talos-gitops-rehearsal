# Ephemeral GitOps IDP (Local Edition)

A deterministic, high-speed ephemeral Kubernetes environment for local development.
It provisions a single Talos Linux cluster on a workstation directly via `talosctl` (Docker provisioner), with one in-cluster Flux loop reconciling the turnkey payload.
Cluster API (CAPI) is deferred to a future cloud milestone; what carries over to that cloud deployment unchanged is the GitOps workflow and the application/workload overlay, not the provisioning mechanism itself.
Secrets are SOPS/AGE-encrypted at rest with a software AGE key in v1; a hardware-bound YubiKey key is a planned follow-on hardening milestone, not a v1 requirement.

See [docs/planning/PRD.md](docs/planning/PRD.md) for the full product requirements, [docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md](docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md) for the implementation plan, and [docs/planning/ZOR-ephemeral-gitops-idp-2026-07-06.md](docs/planning/ZOR-ephemeral-gitops-idp-2026-07-06.md) for the zoom-out review behind the current architecture (the 2026-07-05 ZOR is superseded and kept for history).

## Architecture

1. **Target cluster (Talos Linux)** - a single `talosctl cluster create` (Docker provisioner) cluster, 1 control plane + 2 workers, with Cilium as CNI/kube-proxy replacement.
   No local management cluster and no CAPI exist in v1 - see `docs/planning/ADR-capd-talos-bootstrap-incompatibility-2026-07-06.md` for why.
2. **GitOps loop** - one Flux instance inside the target cluster reconciling the turnkey payload (`clusters/workload/`) from this repository.
3. **Bootstrap security** - a `mise` task decrypts the project's SOPS/AGE-encrypted secrets and injects them into the cluster.

## Project Structure

```text
.
├── .config/
│   ├── mise/          # Task orchestration and tool versioning (mise)
│   ├── sops/           # SOPS/AGE project secrets (age keypair, config)
│   ├── lefthook.yaml   # Git hooks (lint, secrets-leak guards, SOPS integrity check)
│   ├── vale/           # Prose linting (em dash, custom RKA rules)
│   ├── markdownlint/   # Markdown structural linting
│   ├── talos/          # Talos machine-config patches (CNI/kube-proxy disable) for talosctl
│   └── cliff.toml      # git-cliff changelog generation config
├── clusters/workload/  # Flux-reconciled turnkey payload (CAPI-consumability contract in its README)
│   ├── flux-system/    # Flux controllers + GitRepository/Kustomization source-and-sync objects
│   └── infrastructure/
│       ├── cilium/       # Cilium HelmRelease, adopting the bootstrap task's imperative install
│       └── cert-manager/ # cert-manager HelmRelease + local Root CA issuer chain (controllers/, configs/)
├── docs/
│   └── planning/       # PRD, plan, ADRs, and zoom-out reviews for this project
└── docs/LICENSE
```

## Getting Started

### Prerequisites

- Docker
- [mise](https://mise.jdx.dev/)

### Development Tasks

```bash
mise run lint             # Run all linters (shfmt, shellcheck, links, vale, markdownlint)
mise run hooks             # Sync Lefthook and run the pre-commit pipeline manually
mise run sops:project:manage   # Create/edit the encrypted project secrets file
mise run app:start         # Start the app via Docker Compose
```

The full bootstrap chain is defined under `test-talos-spike:*` (see `.config/mise/tasks/test-talos-spike.toml`); run `mise run test-talos-spike:all` to provision a cluster, install Cilium, bootstrap Flux to reconcile `clusters/workload/` from Git (adopting the Cilium release in place), and drive all three verification gates (Cilium/eBPF compatibility, cross-node pod connectivity, LoadBalancer IP allocation and reachability), or `mise run test-talos-spike:teardown` to tear it back down.

## Quality Standards

- **Automated Hooks**: Lefthook runs linting and SOPS/secrets-leak guards before every commit.
- **Zero Plaintext**: No decrypted credentials persist on local disk; secrets are SOPS/AGE-encrypted at rest (software AGE key in v1; see Architecture above).
- **Prose Linting**: vale and markdownlint enforce this project's documentation conventions (no em dashes, one sentence per line).
