---
id: progress
title: Progress
status: active
version: 0.1.5
date: 2026-07-22
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
- Frontmatter gate restored and rule-current: `scripts/validate-frontmatter.sh`
  matches `rka-template` v0.4.0 (rules 1-7) and passes green on all 11 governed
  documents; the `lint:frontmatter` task hard-fails if the script goes missing.
- Upstream conventions verified current (2026-07-22 survey): the released
  RKA, `agent-standards`, and `rka-template` v0.4.0 conventions are all applied.
  The RKA ADR-0013 spec-lifecycle gate (validator rules 8 and 9) is pending a
  tagged `rka-template` release before adoption (see `activeContext.md`).
- Second RKA lifecycle pass (2026-07-22): ADR-0003 through ADR-0006 promoted
  `draft -> active` on re-verified evidence (`docs/reviews/`), ADR-0007 accepted
  (`adr_status: accepted`, `active`) settling the scope-identity decision, and
  `context.md` plus the constitution promoted to `active` (definition-of-done
  synthesis confirmed).
  The PRD was inducted into governance as `knowledge/PRD.md` (`type: prd`,
  entered at `draft`); the `docs/planning/PRD.md` original is retained ungoverned
  with its `status` stripped.

## What's left

- Phase 4 (lifecycle, idempotency, metrics hardening): not started.
- Phase 5 (YubiKey hardening) and M-CAPI (real cloud target via Cluster
  API): unscheduled, deferred by design.
- State persistence / DB re-hydration across ephemeral cycles: unresolved
  open question (`context.md`).
- Promote the newly-inducted `knowledge/PRD.md` from `draft` to `active`: its
  content is already verified by the built, live-tested system, so this is a
  ready informal-verification step.
- Canonical promotion of the `active` ADRs (ADR-0003..0007) is a later gate:
  they should season as `active` through the Phase 4 hardening pass and at
  least one more consuming change before an evidence-backed canonical review.
- Retire the completed `docs/specs/001-governance-parity/` bundle once the
  RKA ADR-0013 spec-lifecycle gate ships in a tagged `rka-template` release:
  migrate it into `knowledge/specs/`, add an extraction record, set
  `status: archived`.

## Known issues / limitations

- Single-user by design: Dex's GitHub connector carries no org/team
  restriction; must be restricted before the tunnel ever serves a second
  person (constitution non-goals; `clusters/workload/README.md`).
- Multi-customer / multi-tenant separation has no foundation in this repo;
  treating this repo as "the IDP" overstates its scope (settled by ADR-0007:
  this repo is the single-tenant rehearsal tool, the multi-customer IDP is a
  separate future project).
- Devcontainer couples to two sibling repos' churn: the digest-pinned
  `devbase` image (bootstrap-workspace) and the mounted `agent-standards`
  checkout; both update manually.
