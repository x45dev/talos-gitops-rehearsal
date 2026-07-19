---
id: progress
title: Progress
status: active
version: 0.1.1
date: 2026-07-19
type: context
---

# Progress

What works, what's left, and known issues.
Created by the 2026-07-19 cross-repo ecosystem review; state synthesized from
`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md`, the constitution's
phased-status section, and the review's survey of this repo.

## What works

- Phase 0: single Talos cluster (1 control-plane + 2 workers) provisioned
  directly via `talosctl cluster create` (Docker provisioner), Cilium
  installed, all three engineering gates green, reproducible across
  teardown cycles.
- Phase 2: in-cluster Flux loop reconciling `clusters/workload/`, including
  Cilium adoption.
- Phase 3: full turnkey payload live-verified end to end - cert-manager with
  a local Root CA, Dex (GitHub OIDC), Cloudflare Tunnel.
- Lifecycle driven by mise tasks (`test-talos-spike:all` / `:teardown`);
  cluster creation imperative-but-idempotent, in-cluster state declarative.
- First real RKA lifecycle exercised here: ADR-0001/ADR-0002 promoted
  `draft -> active -> canonical` through the evidence-backed gate
  (2026-07-13), with the promotion evidence retained in `docs/reviews/`.
- Load-bearing pins recorded with rationale: Cilium 1.18.11 (ADR-0002,
  1.19.x breaks host-network DNS on Talos 1.13), Flux 2.9.0.

## What's left

- Phase 4 (lifecycle, idempotency, metrics hardening): not started.
- Phase 5 (YubiKey hardening) and M-CAPI (real cloud target via Cluster
  API): unscheduled, deferred by design.
- State persistence / DB re-hydration across ephemeral cycles: unresolved
  open question (`context.md`).
- Working-state and governance hygiene from the 2026-07-19 review: restore
  the missing frontmatter validator, progress the `draft` ADR/constitution
  backlog, decide the scope-identity and rename questions
  (see `activeContext.md`).

## Known issues / limitations

- `scripts/validate-frontmatter.sh` is referenced by the lint task but does
  not exist; frontmatter validation is currently a silent no-op.
- Single-user by design: Dex's GitHub connector carries no org/team
  restriction; must be restricted before the tunnel ever serves a second
  person (constitution non-goals; `clusters/workload/README.md`).
- Multi-customer / multi-tenant separation has no foundation in this repo;
  treating this repo as "the IDP" overstates its scope (see the scope
  decision in flight).
- Devcontainer couples to two sibling repos' churn: the digest-pinned
  `devbase` image (bootstrap-workspace) and the mounted `agent-standards`
  checkout; both update manually.
