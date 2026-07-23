---
id: constitution
title: Ephemeral GitOps IDP (Local Edition) - Constitution
status: draft
version: 0.1.2
date: 2026-07-22
type: constitution
---

# Constitution - Ephemeral GitOps IDP (Local Edition)

Drafted by brownfield discovery from pre-existing project documentation.
Every claim below is cited to its source or marked as an inference with a confidence
marker, per the discovery instruction set section 3.
See `docs/raw/discovery-report-2026-07-13.md` for the full evidence ledger and open
questions.

## Why this project exists

This project delivers a deterministic, high-speed ephemeral Kubernetes environment for
local development: it provisions a single Talos Linux cluster on a workstation directly
via `talosctl` (Docker provisioner), with one in-cluster Flux loop reconciling a turnkey
GitOps payload (`README.md` lines 1-8).

The parity it is built to buy is deliberately narrow: the GitOps workflow and the
application/workload overlay are meant to carry over unchanged to a later cloud
(Cluster API / AWS) deployment; the cluster-provisioning mechanism itself is not
(`README.md` lines 1-8; `docs/planning/PRD.md` Section 1, lines 19-25; Section 5, lines
102-118).
The PRD is explicit that overstating this parity is the main way the project can
disappoint, so the boundary is treated as a first-class requirement rather than an
aspiration (`docs/planning/PRD.md` Section 1, lines 24-25).

Secrets are kept off Git via SOPS/AGE encryption at rest, with a software AGE key
accepted for v1 and a hardware-bound (YubiKey) key deferred as a later hardening
milestone (`README.md` line 6; `docs/planning/PRD.md` Section 3.2, lines 62-69).

## Invariants

These must hold throughout the project, per the cited sources:

1. **No plaintext secrets in Git.** No decrypted credentials are ever committed; the
   project AGE key lives at `.config/sops/age/keys.txt` and is gitignored
   (`docs/planning/PRD.md` Section 3.2, lines 64-65; `README.md` "Quality Standards",
   line 64).
   `mise`'s SOPS integration is configured to fail loudly rather than silently on
   decryption failure (`sops.strict = true`, `.config/mise/config.toml` line 44).
2. **The CAPI-consumability contract.** Nothing under `clusters/workload/` may assume
   how the cluster it runs on was provisioned: no `talosctl`-specific node names or
   labels, no local filesystem paths (`hostPath`, home-directory paths), and no
   reference to the Docker provisioner's network topology
   (`clusters/workload/README.md` lines 10-26; `docs/planning/PRD.md` Section 5, lines
   113-115).
   This contract is what keeps the deferred CAPI milestone a bolt-on rather than a
   rewrite (`docs/planning/PRD.md` Section 5, line 115) and it received a
   doubt-driven-development review before standing
   (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` lines 114-115).
3. **The idempotency bar.** Cluster existence is imperative but idempotent: re-running
   the bootstrap task against an already-correct cluster is a no-op, and every
   operation detects its actual precondition and self-heals rather than sleeping or
   silently skipping - a fixed `sleep 15` in an earlier task revision was explicitly
   called out as below this bar and fixed
   (`docs/planning/PRD.md` Section 3.3, lines 71-79;
   `docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` "Current state" bullet on the
   CAPD-era `validate` task, lines 34-35).
   Everything inside the cluster, by contrast, is declarative and continuously
   reconciled by Flux from Git (`docs/planning/PRD.md` Section 3.3, line 78).
4. **Deterministic, zero-residue teardown.** Teardown must destroy the Talos cluster,
   prune Docker containers/networks, and leave zero residue in user-global state (no
   leftover context in `~/.kube/config` or `~/.talos/config`, no leftover `talosctl`
   cluster-state directory) (`docs/planning/PRD.md` Section 3.3, lines 73-75, and
   Section 7 "Cleanliness", line 153).

## Hard environmental constraints

- **Docker-only host dependency.** Established as a hard line during the 2026-07-06
  interview behind the substrate re-frame; it independently eliminates any
  Incus/LXD-based alternative regardless of other considerations
  (`docs/planning/ZOR-ephemeral-gitops-idp-2026-07-06.md` Section 4, lines 61-66;
  `docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` "Decisions", item 1, lines
  192-193).
- **Target environment is a single Ubuntu 26.04 workstation**, not a shared or
  multi-user environment (`docs/planning/PRD.md` header, line 12; corroborated by
  repeated "single-developer local dev tool" framing of accepted security gaps in
  `clusters/workload/README.md` "Known limitations", lines 91-129).
- **Host-native toolchain on the laptop, not a devcontainer.** The full toolchain is
  `mise`-managed; the only Docker requirement is that `talosctl`'s provisioner reach a
  Docker daemon socket (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` Phase 1,
  lines 87-94). See ADR-0003. A `.devcontainer/` was later added for cross-machine dev
  and agent sessions on a second host (ADR-0006 reopening ADR-0003); its default
  container holds no Docker socket, with that host-root-equivalent access confined to
  an opt-in `compose.cluster.yaml` overlay used only on a cluster-run host.
- **Cluster topology: 1 control-plane + 2 workers is required, not incidental.** Talos
  control-plane nodes are `NoSchedule`-tainted by default, so a single-worker topology
  would let the cross-node connectivity gate pass vacuously
  (`docs/planning/PRD.md` Section 2, item 1, lines 31-32).
- **Version pins are load-bearing, not incidental choices**: Cilium 1.18.11 (not
  1.19.x - see ADR-0002), Kubernetes 1.35.x, Flux `2.9.0` (pinned because Flux's
  Cilium-adoption reconcile behavior is version-dependent, `.config/mise/config.toml`
  line 61).

## Effective definition of done

Synthesized from the PRD's engineering gates and success metrics; no single document
states a unified "definition of done" verbatim, so this synthesis is an inference
(medium confidence: two independent sections agree on the same shape).

- **Three engineering gates must pass** before the pipeline is built on top, and remain
  active afterward: Cilium/eBPF compatibility, cross-node pod connectivity (provably
  crossing a node boundary), and `LoadBalancer` IP allocation *and* host reachability
  as separate, both-required mechanisms (`docs/planning/PRD.md` Section 4, lines
  82-100).
- **Success metrics** (`docs/planning/PRD.md` Section 7, lines 147-153):
  - Spin-up time under 10 minutes from `mise` command to every payload
    `HelmRelease`/`Kustomization` reporting `Ready`.
  - Workflow and application-overlay parity with the future cloud (CAPA) deployment
    (the cluster-provisioning mechanism itself is explicitly excluded from this
    metric).
  - Zero orphaned Docker containers/networks and zero config residue after teardown.
- **Phased delivery status as of the discovery date** (inference, high confidence -
  stated directly in the plan): Phases 0-3 (spike-to-green, host-native tooling
  decision, GitOps repository structure, and the full turnkey payload of Cilium,
  cert-manager, Dex, and Cloudflare Tunnel) are done and live-verified as of
  2026-07-12; Phase 4 (lifecycle/idempotency/metrics hardening) has not started; Phase
  5 (YubiKey hardening) and Milestone M-CAPI (re-introducing CAPI for a real cloud
  target) are deliberately unscheduled
  (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` lines 44-217, especially the
  per-phase "Status:" lines and "Immediate next action", lines 214-217).

## Non-goals

- **CAPI, CABPT/CACPPT, and a local management cluster are explicitly out of scope for
  v1.** They are deferred to an unscheduled future Milestone M-CAPI, triggered only by
  a real cloud (CAPA) target being planned, not by v1 completion. See ADR-0001.
  (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` "Milestone M-CAPI", lines
  173-179.)
- **Hardware-bound (YubiKey) secret decryption is not a v1 requirement.** It was
  originally written as a hard requirement and was explicitly reclassified as a
  follow-on hardening milestone (`docs/planning/PRD.md` Section 3.2, lines 66-69;
  Section 8, line 158).
- **Multi-user / access-restricted identity is out of scope.** Dex's GitHub connector
  has no org/team restriction; this is accepted for "a single-user local ephemeral IDP"
  and flagged to revisit only if the tunnel ever serves more than one person
  (`clusters/workload/README.md` lines 126-129).
- **Fully declarative cluster provisioning is not a v1 goal.** Local cluster
  provisioning is an imperative (if idempotent) `talosctl` invocation; fully
  declarative provisioning is explicitly deferred to the CAPI milestone
  (`docs/planning/PRD.md` Section 3.3, lines 79-80).
- **State persistence / data re-hydration across ephemeral cycles is unresolved and
  explicitly not v1 work.** Recorded as an open decision, to be addressed only if a
  real need for re-hydrating database state across reboots emerges
  (`docs/planning/PRD.md` Section 6, line 141;
  `docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` "Decisions" - "Open", lines
  210-212).

## Open questions for the human

- **PRD induction - resolved 2026-07-22.** The PRD (`docs/planning/PRD.md`) is kept as
  ungoverned working material rather than inducted as a `knowledge/specs/` feature
  specification.
  Its illegal outside-`knowledge/` `status` field was stripped to settle the halfway
  state RKA forbids (ungoverned documents carry no `status`, RFC-001 section 2).
  Induction remains available later if the PRD ever needs the lifecycle, but it is not
  governed knowledge today.
- **Unified definition-of-done synthesis - still open.** No document states a single
  unified "definition of done" in one place; the synthesis above draws it from two
  sections (engineering gates + success metrics) that agree in shape but were never
  stated together.
  Confirm this synthesis matches intent before promoting this constitution past
  `draft`; this is the sole remaining gate on the constitution's own promotion.
