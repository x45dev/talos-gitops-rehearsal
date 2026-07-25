---
okf_version: "0.1"
---

# Ephemeral GitOps IDP - Knowledge Bundle

This is the bundle-root index for this repository's governed knowledge (RFC-003 section 5).
It enumerates every governed document so an agent can read the descriptions and load only what a task needs, rather than loading the whole bundle.
This file is OKF bundle structure, not a governed knowledge document: it carries no RKA frontmatter and no `status` (ADR-0011).
Rule 7 of `scripts/validate-frontmatter.sh` keeps it honest - every governed document must appear here, and every entry must resolve.

## Foundation

* [Constitution](constitution.md) - Why this project exists, its four invariants (no plaintext secrets, the CAPI-consumability contract, the idempotency bar, zero-residue teardown), hard environmental constraints, the effective definition of done, and the non-goals.
* [Context](context.md) - The combined product, technical, and system-patterns context: the pinned stack (Talos, Cilium 1.18.11, Flux 2.9.0, SOPS/AGE), the architectural patterns, the accepted v1 gaps, and release-pinned upstream tracking.

## Architecture Decision Records

* [ADR-0001 - Drop CAPD for local Talos provisioning](adr/ADR-0001.md) - CAPD's `DockerMachine` controller cannot consume Talos machine configs, so v1 provisions directly with `talosctl` and defers CAPI to the cloud milestone. Canonical.
* [ADR-0002 - Pin Cilium to 1.18.11](adr/ADR-0002.md) - Cilium 1.19.x with `kubeProxyReplacement` breaks host-network DNS on Talos 1.13; the pin is load-bearing, not incidental. Canonical.
* [ADR-0003 - Host-native mise toolchain](adr/ADR-0003.md) - The v1 toolchain is `mise`-managed on the host rather than a devcontainer; reopened in part by ADR-0006.
* [ADR-0004 - Persistent deploy key and scratch-branch iteration](adr/ADR-0004.md) - Flux authenticates to this repository with a persistent read-only SSH deploy key, and local iteration repoints the `GitRepository` at a scratch branch.
* [ADR-0005 - Layered controllers/configs Kustomization pattern](adr/ADR-0005.md) - CRD-provider components (cert-manager) split into `controllers/` and `configs/` Kustomizations with `dependsOn`; components without CRD-ordering needs stay flat.
* [ADR-0006 - Add a devcontainer for cross-machine sessions](adr/ADR-0006.md) - A `.devcontainer/` for a second host, with the Docker socket and host networking confined to an opt-in overlay used only on a cluster-running host.
* [ADR-0007 - Scope identity](adr/ADR-0007.md) - This repository is the single-tenant, single-cluster local GitOps rehearsal tool; the multi-customer ephemeral IDP is a separate future project. Also records the deferred repository rename and its blast radius.
* [ADR-0008 - Keep the PRD unmanaged](adr/ADR-0008.md) - A pre-existing PRD is an extraction source, never an induction candidate; its durable content lives in the constitution, context, and ADRs.
* [ADR-0009 - Adopt the ADR-0013 spec-lifecycle gate early](adr/ADR-0009.md) - A scoped exception to ADR-0012's release-train rule, adopting validator rules 8 and 9 ahead of the train, with a standing obligation to reconcile when they ship.

## Feature Specifications

* [001 Governance parity - spec](specs/001-governance-parity/spec.md) - Restore the frontmatter gate, migrate the knowledge base to the six-field schema, and settle scope. Archived; carries the bundle's extraction record.
* [001 Governance parity - plan](specs/001-governance-parity/plan.md) - Implementation plan for the governance-parity work. Archived.
* [001 Governance parity - tasks](specs/001-governance-parity/tasks.md) - Task list and execution evidence for the governance-parity work. Archived.
* [002 Phase 4 lifecycle hardening - spec](specs/002-phase-4-lifecycle-hardening/spec.md) - End-to-end idempotent bootstrap, self-verifying zero-residue teardown, and the day-2 Cilium record. Draft; not yet executed. The spin-up measurement workstream was withdrawn on 2026-07-25.
* [002 Phase 4 lifecycle hardening - plan](specs/002-phase-4-lifecycle-hardening/plan.md) - Implementation plan grounded in the `test-talos-spike` task chain, with both gate-3 adversarial reviews recorded. Draft.
* [002 Phase 4 lifecycle hardening - tasks](specs/002-phase-4-lifecycle-hardening/tasks.md) - Task list T001 to T016 (T009-T011 withdrawn), with HUMAN markers on the two owner-only decisions. Draft; requires a host with Docker and the full `mise` toolchain.

## Working Context

* [Active Context](activeContext.md) - The current focus, decisions settled or in flight, upstream-tracking state, and the immediate to-do list. Read this first in a new session.
* [Progress](progress.md) - What works, what is left, and the known issues and accepted limitations.
