---
id: progress
title: Progress
status: active
version: 0.1.13
date: 2026-07-26
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
- Frontmatter gate restored and extended: `scripts/validate-frontmatter.sh`
  carries the `rka-template` v0.4.0 rules 1-7 plus the ADR-0013 rules 8, 9a and
  9b (ported early per ADR-0009), and passes green on all 20 governed documents;
  the `lint:frontmatter` task hard-fails if the script goes missing.
- Upstream conventions verified current (2026-07-22 survey): the released
  RKA, `agent-standards`, and `rka-template` v0.4.0 conventions are all applied.
- CI gate added (2026-07-25): `.github/workflows/ci.yml` re-runs the governance
  and docs checks (frontmatter validator, markdownlint, em dash, shellcheck) on
  pull requests and pushes to `main`.
  Until now every gate lived only in the local Lefthook hook, so any commit made
  without the `mise` toolchain (a cloud agent session, a fresh clone) reached
  `main` ungated.
  CI deliberately does not invoke `mise`: `sops.strict = true` means any
  `mise run` tries to decrypt the project secrets, and giving CI the AGE key
  would violate the zero-plaintext invariant.
  No cluster tests run in CI.
- Spin-up metric commitment closed (2026-07-25, ADR-0010): the 002 descope left PRD
  Section 7, PLAN Phase 4 item 3, and the constitution's definition of done all
  naming a per-stage budget that nothing carried.
  The metric stands unchanged but is now recorded as deliberately uninstrumented,
  with a revisit trigger, and all three documents point at the ADR instead of
  claiming a carrier. Whether the target is currently met is honestly unknown.
- Bundle index present (2026-07-25): `knowledge/index.md` enumerates all 20
  governed documents with descriptions, so an agent can load only what a task
  needs.
  Its presence activates validator rule 7 (every governed document listed, every
  entry resolves), which was latent while no index existed; both halves proven by
  seeded violation.
- Spec-lifecycle gate live (2026-07-24, ADR-0009): feature specs are governed
  bundles under `knowledge/specs/<NNN>-<slug>/`, and the validator now fails a
  bundle whose tasks are all complete but is not `archived` (9b), a bundle with
  mixed statuses (9a), or an archived document with no `Extraction record` (8).
  All three were proven to fail by seeded violation before landing.
- Second RKA lifecycle pass (2026-07-22): ADR-0003 through ADR-0006 promoted
  `draft -> active` on re-verified evidence (`docs/reviews/`), ADR-0007 accepted
  (`adr_status: accepted`, `active`) settling the scope-identity decision, and
  `context.md` plus the constitution promoted to `active` (definition-of-done
  synthesis confirmed).
  The PRD is kept unmanaged as an extraction source per ADR-0008 (a brief
  induction into `knowledge/PRD.md` was reverted to avoid PRD/constitution
  redundancy); `docs/planning/PRD.md` remains ungoverned with its `status`
  stripped.

## What's left

- Phase 4 (lifecycle and idempotency hardening): not started; spec bundle
  `knowledge/specs/002-phase-4-lifecycle-hardening/` is authored and reviewed.
  Descoped 2026-07-25 (v0.2.0): spin-up measurement and budget withdrawn to
  non-goals (not a problem in real use, revisit trigger recorded); the surviving
  work proves constitution invariants 3 (idempotency) and 4 (zero-residue
  teardown), which are currently asserted rather than verified.
- Phase 5 (YubiKey hardening) and M-CAPI (real cloud target via Cluster
  API): unscheduled, deferred by design.
- State persistence / DB re-hydration across ephemeral cycles: unresolved
  open question (`context.md`).
- ADR-0010 is the only governed document still at `draft`; promote it to
  `active` once it has seasoned (recorded 2026-07-25).
- Canonical promotion of the `active` ADRs (ADR-0003..0007) is a later gate:
  they should season as `active` through the Phase 4 hardening pass and at
  least one more consuming change before an evidence-backed canonical review.
- Reconcile the early-ported validator rules 8/9 against the released version
  when a tagged `rka-template` release ships them, and record any divergence
  here (ADR-0009's standing obligation).

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
