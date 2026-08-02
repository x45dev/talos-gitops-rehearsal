# talos-gitops-rehearsal

A single-tenant, single-workstation local GitOps rehearsal rig: one Talos cluster in Docker, Cilium, one in-cluster Flux loop.

It provisions that cluster directly via `talosctl` (Docker provisioner) and reconciles the turnkey payload from this repository, deterministically and at speed, so the patterns can be proven locally before they are carried anywhere else.
The multi-customer ephemeral IDP is a separate future project that consumes these patterns; it is out of scope here by decision (see `knowledge/adr/ADR-0007.md`).
Cluster API (CAPI) is deferred to a future cloud milestone; what carries over to that cloud deployment unchanged is the GitOps workflow and the application/workload overlay, not the provisioning mechanism itself.
Secrets are SOPS/AGE-encrypted at rest with a software AGE key in v1; a hardware-bound YubiKey key is a planned follow-on hardening milestone, not a v1 requirement.
This public repository carries no secret material of its own: no committed ciphertext and no credentials.
Bring your own by creating the machine-local, gitignored `.config/mise/.env.sops.yaml` from `.config/mise/.env.yaml.template` (see Getting Started).

See [docs/planning/PRD.md](docs/planning/PRD.md) for the full product requirements, [docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md](docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md) for the implementation plan, and [docs/planning/ZOR-ephemeral-gitops-idp-2026-07-06.md](docs/planning/ZOR-ephemeral-gitops-idp-2026-07-06.md) for the zoom-out review behind the current architecture (the 2026-07-05 ZOR is superseded and kept for history).

## Architecture

1. **Target cluster (Talos Linux)** - a single `talosctl cluster create` (Docker provisioner) cluster, 1 control plane + 2 workers, with Cilium as CNI/kube-proxy replacement.
   No local management cluster and no CAPI exist in v1 - see `docs/planning/ADR-capd-talos-bootstrap-incompatibility-2026-07-06.md` for why.
2. **GitOps loop** - one Flux instance inside the target cluster reconciling the turnkey payload (`clusters/workload/`) from this repository.
3. **Bootstrap security** - a `mise` task decrypts your machine-local SOPS/AGE-encrypted secrets and injects them into the cluster.
   Flux itself needs no credential: this repository is public, so its `GitRepository` clones anonymously over HTTPS.

Where `knowledge/` and `docs/planning/` call something "live-verified", that records a manual end-to-end run against a real cluster on 2026-07-12, not a continuously re-executed check: CI gates documentation and lint only, and never stands a cluster up (see Quality Standards below).

## Project Structure

```text
.
├── .devcontainer/      # Cross-machine dev/agent devcontainer (default: no Docker access;
│                       # compose.cluster.yaml: opt-in Docker-socket + host-networking overlay
│                       # for cluster-run hosts - see ADR-0006)
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
│       ├── cilium/            # Cilium HelmRelease, adopting the bootstrap task's imperative install
│       ├── cert-manager/      # cert-manager HelmRelease + local Root CA issuer chain (controllers/, configs/)
│       ├── dex/                # Dex HelmRelease - GitHub OIDC identity provider, TLS via local-ca
│       └── cloudflare-tunnel/  # cloudflared Deployment - Cloudflare Tunnel ingress fronting Dex
├── .github/workflows/  # CI: the governance and docs gate (no cluster tests - see the workflow header)
├── knowledge/          # Governed knowledge base (RKA). Gated by scripts/validate-frontmatter.sh
│   ├── index.md        # Bundle index - lists every governed document (see Quality Standards)
│   ├── constitution.md # Why this project exists, its invariants, constraints, and non-goals
│   ├── context.md      # Combined product/technical/system-patterns context
│   ├── activeContext.md # Current focus and to-do (read first in a new session)
│   ├── progress.md     # What works, what is left, known issues
│   ├── adr/            # Architecture Decision Records (ADR-NNNN)
│   └── specs/          # Governed feature-spec bundles (<NNN>-<slug>/{spec,plan,tasks}.md)
├── scripts/            # validate-frontmatter.sh (the RKA gate), devcontainer-up.sh
├── tests/              # bats suite for the RKA gate itself (mise run test; runs in CI)
├── docs/
│   ├── planning/       # PRD, plan, and the pre-RKA dated ADRs and zoom-out reviews (ungoverned)
│   ├── reviews/        # Point-in-time review records (promotion evidence) - ungoverned
│   ├── raw/            # Discovery working material - ungoverned
│   └── CHANGELOG.md    # Auto-generated by git-cliff (`mise run changelog`, also regenerated at pre-commit) - never hand-edited
└── docs/LICENSE
```

Everything under `knowledge/` is governed: it carries RKA frontmatter, moves through the `draft` to `active` to `canonical` lifecycle, and is validated on every commit.
Everything under `docs/` is ungoverned working material and carries no lifecycle `status`.

## Conventions

`knowledge/` follows the Repository Knowledge Architecture (RKA) standard - the frontmatter schema, the `draft`/`active`/`canonical` lifecycle, and the promotion rules all come from it.
RKA lives in `x45dev/repository-knowledge-architecture`; its public release is in progress, so this reference is deliberately a name rather than a link.

Some agent-workflow references in `knowledge/` and in configuration comments - `agent-standards`, `bootstrap-workspace`, `devbase` - point at private upstream conventions of the author's.
They are retained as historical record of how decisions were actually made, and nothing in this repository depends on them being reachable.

## Getting Started

### Prerequisites

- Docker
- [mise](https://mise.jdx.dev/)

### Development Tasks

```bash
mise run lint             # Run all linters (shfmt, shellcheck, links, vale, markdownlint, frontmatter)
mise run test              # Run the test suites (bats: the frontmatter validator's own rules)
mise run hooks             # Sync Lefthook and run the pre-commit pipeline manually
mise run changelog         # Regenerate docs/CHANGELOG.md from git history (git-cliff, Conventional Commits)
mise run sops:project:manage   # Create/edit your machine-local encrypted secrets file
mise run app:start         # Start the app via Docker Compose
```

The full bootstrap chain is defined under `test-talos-spike:*` (see `.config/mise/tasks/test-talos-spike.toml`); run `mise run test-talos-spike:all` to provision a cluster, install Cilium, bootstrap Flux to reconcile `clusters/workload/` from Git (adopting the Cilium release in place), and drive all three verification gates (Cilium/eBPF compatibility, cross-node pod connectivity, LoadBalancer IP allocation and reachability), or `mise run test-talos-spike:teardown` to tear it back down.

### Devcontainer (cross-machine dev/agent sessions)

`.devcontainer/` gives a second host (e.g. a Tailscale-joined VPS) the same
`mise`-managed toolchain as the laptop, for editing, linting, committing, and
unattended agent sessions - the laptop's host-native workflow above remains the
default for local work.
Its default `compose.yaml` service holds no Docker socket and no host
networking, so it has no path to the host.
Only on a host that actually runs the Talos cluster (the laptop) layer the
opt-in overlay to grant `talosctl` what it needs:
`docker compose -f compose.yaml -f compose.cluster.yaml up -d`.
See ADR-0006 for the full rationale and the security split behind it.

## Quality Standards

- **Automated Hooks**: Lefthook regenerates `docs/CHANGELOG.md` and runs linting and SOPS/secrets-leak guards before every commit.
- **CI**: `.github/workflows/ci.yml` re-runs the governance and docs gate (frontmatter, the frontmatter validator's own bats suite, markdown, em dashes, shellcheck) on pull requests and pushes to `main`, so a commit made without the local toolchain is still checked.
  It installs the few tools the governance gates need and calls them directly rather than going through `mise`, and runs no cluster tests.
- **Tested gates**: the frontmatter validator has its own `bats` suite (`tests/validate-frontmatter.bats`, 26 tests covering all nine RFC-003 rules), so the governance gate is itself gated rather than trusted.
  It runs in CI rather than the pre-commit hook, because it costs about 1m38s against the local gate's ~25s; run it locally with `mise run test`.
- **Zero Plaintext**: No decrypted credentials persist on local disk; secrets are SOPS/AGE-encrypted at rest (software AGE key in v1; see Architecture above).
  The one plaintext file, the gitignored `.config/mise/.env.local`, holds only the Cloudflare account and zone IDs, which identify an account rather than authenticate to it.
- **No Committed Secrets**: neither plaintext nor ciphertext credentials are tracked in this repository.
  Both `.config/mise/.env.sops.yaml` and `.config/mise/.env.local` are gitignored; only their templates are committed, and a Lefthook guard rejects either if it is ever staged.
- **Prose Linting**: vale enforces the no-em-dash rule and markdownlint enforces markdown structure; one sentence per line is a house convention, not a mechanical gate.
- **Keep `knowledge/index.md` current**: the bundle index must list every governed document, and every entry must resolve.
  Adding, removing, or renaming anything under `knowledge/` therefore means editing `index.md` in the same change, or the frontmatter gate (rule 7) fails the commit.
