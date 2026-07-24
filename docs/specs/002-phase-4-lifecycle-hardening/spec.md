---
id: spec-002-phase-4-lifecycle-hardening
title: Phase 4 - lifecycle, idempotency, and metrics hardening
status: draft
version: 0.1.0
date: 2026-07-22
type: spec
---

# Feature Specification: Phase 4 - lifecycle, idempotency, and metrics hardening

**Branch**: `002-phase-4-lifecycle-hardening` | **Created**: 2026-07-22 | **Status**: draft
**Input**: `docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` "Phase 4"; `docs/planning/PRD.md`
Sections 3.3 and 7; `knowledge/constitution.md` invariants 3 (idempotency bar) and 4 (zero-residue
teardown) and the effective definition of done; `knowledge/progress.md` "What's left".

## Why (problem statement)

Phases 0-3 are done and live-verified: a single Talos cluster with Cilium, the in-cluster Flux loop,
and the full turnkey payload (cert-manager, Dex, Cloudflare Tunnel) stand up end to end. What is not yet
hardened is the lifecycle around that payload. Three obligations the constitution and PRD already state
are only partially met:

- **Idempotency is proven for Phase 0, not end to end.** The spike work established the idempotency bar
  (every step detects its precondition and self-heals; a fixed `sleep 15` was called out as below it),
  and Phase 0 re-entry is idempotent. But the full bootstrap chain through the Flux-reconciled payload
  has not been driven as a single re-runnable no-op: a re-run against an already-converged environment
  must change nothing and must not race or duplicate work.
- **Teardown zero-residue is an invariant, not yet a verified one.** Constitution invariant 4 and PRD
  Success Metric 3 require teardown to destroy the cluster and leave zero orphaned Docker
  containers/volumes/networks and zero config residue (no context in `~/.kube/config` or
  `~/.talos/config`, no leftover `talosctl` state directory). Today teardown performs the destroy but
  does not verify the invariant.
- **Spin-up time is unmeasured against its target.** PRD Success Metric 1 is under 10 minutes from `mise`
  command to every payload `HelmRelease`/`Kustomization` reporting `Ready`. Only a Phase 0 baseline
  exists (cluster + Cilium + gates, ~5-6 min); the full Flux-driven payload has not been measured, and
  the plan flags the Flux-sequenced components (cert-manager, Dex, Cloudflare Tunnel) as the likely
  blowout stages.

Until this feature lands, the environment works but its lifecycle guarantees rest on assertion rather
than on a re-runnable, measured, self-verifying pipeline.

## User stories

- **US1 - Developer, safe re-run**: As the developer, re-running the bootstrap task against an
  already-converged environment is a no-op that changes nothing and completes fast, so I can re-invoke it
  freely without fear of duplicated work, races, or drift.
- **US2 - Developer, clean teardown**: As the developer, teardown destroys the cluster and then proves it
  left zero residue (containers, volumes, networks, and user-global kube/talos config), so a later
  `setup` starts from a genuinely clean slate and my workstation does not accumulate cruft across cycles.
- **US3 - Maintainer, measured spin-up**: As the maintainer, spin-up time is measured per stage against
  the under-10-minute target and recorded as a budget, so a regression or a blowout stage is visible as
  data rather than a vague slowdown, and the named levers can be applied deliberately.

## Functional requirements

- **FR1 - End-to-end idempotent bootstrap.** The bootstrap task is idempotent across the full chain
  (cluster existence, Cilium install/adoption, Flux install, secret injection, payload reconciliation): a
  re-run with the target state already reached is a no-op, and every step detects its actual precondition
  and self-heals rather than sleeping or blindly re-applying. No fixed-duration sleep may stand in for a
  precondition check (the standing idempotency bar).
  Accepted exception: idempotent-by-overwrite external-API writes that have no destructive side effect,
  specifically the `cloudflare-tunnel-bootstrap` ingress-config PUT and DNS upsert, are unconditional by
  design and are not reworked; they are listed explicitly as exceptions rather than counted as blind
  re-applies.
- **FR2 - Hardened, self-verifying teardown.** Teardown runs `talosctl cluster destroy`, removes
  `.kube-*.config`/`.talosconfig`, and then verifies the zero-residue invariant: no Docker containers,
  volumes, or networks remain for the cluster (including the `talosctl`-created network), and no cluster
  context remains in `~/.kube/config` or `~/.talos/config`, and no `talosctl` cluster-state directory
  remains. A residual artifact fails teardown loudly rather than passing silently.
- **FR3 - Staged spin-up measurement and recorded budget.** Spin-up is measured from the `mise` command
  to all-`Ready`, broken into stages (cluster create, Cilium ready, Flux ready, payload `Ready`), and the
  per-stage timings are recorded as a committed baseline budget. The measurement is reproducible from a
  clean `teardown`.
- **FR4 - Budget-overrun levers, applied in order.** If the measured total exceeds 10 minutes, the named
  levers are applied in order and the choice recorded: (1) a host-side pull-through registry mirror the
  ephemeral nodes are configured to use via `talosctl cluster create` registry-mirror flags; (2) relaxing
  `dependsOn` chains where safe; (3) only as a last resort, renegotiating the PRD metric explicitly
  (scope or number), never silently missing it.
- **FR5 - Close or record the day-2 Cilium config-drift gap.** The known limitation that agent-level
  Cilium flag changes have no Flux-side equivalent of the bootstrap task's unconditional `DaemonSet`
  restart is either closed (a reconciled mechanism) or re-recorded as an accepted, dated limitation with
  its trigger, so the idempotency story does not silently exclude day-2 Cilium changes.

## Non-goals (scoped out, with reasons)

- **Phase 5 (YubiKey hardening)** and **Milestone M-CAPI (real cloud target)**: deferred by design
  (constitution non-goals; PLAN Phase 5 / M-CAPI). This spec is v1 lifecycle hardening only.
- **State persistence / data re-hydration across ephemeral cycles**: the constitution's standing open
  question, addressed only if a real need emerges; not v1 work and not this feature.
- **Canonical promotion of the active ADRs**: a separate governance gate; this feature is one of the
  "consuming changes" the ADRs season through, not the promotion itself.
- **New payload components**: this feature hardens the lifecycle around the existing turnkey payload, it
  does not add to it.

## Acceptance criteria

1. **Idempotent re-run (mechanical)**: from a converged environment, a second `all` run reports every
   `kubectl apply` issued by the imperative `test-talos-spike` chain as `unchanged` (zero
   `configured`/`created` lines), performs no cluster re-create and no Cilium re-install (the adoption
   path is skipped), and exits 0 with no errors; the Flux-owned payload is checked by its `Ready`
   conditions staying satisfied, not by apply output, and the accepted idempotent-by-overwrite external
   writes (FR1) are exempt. As a corroborating signal the second run completes in well under half the
   cold-run wall time. Proven twice in a row, both no-op transcripts saved.
2. **Zero-residue teardown, verified**: after `teardown`, an automated check reports zero cluster Docker
   containers/volumes/networks and zero config residue in repo-local and user-global kube/talos config
   and the `talosctl` state directory; a deliberately seeded residual artifact makes the check fail.
3. **Recorded spin-up budget**: a committed per-stage timing record exists (cluster create, Cilium, Flux,
   payload `Ready`) with a total, measured from a clean `teardown`; if over 10 minutes, the applied lever
   (FR4) is recorded with it.
4. **No sub-idempotency-bar sleeps**: a scan of the bootstrap tasks shows no fixed-duration sleep standing
   in for a precondition check; each wait is a retry-until-condition loop.
5. **Day-2 Cilium gap resolved on the record**: FR5 is either implemented or the limitation is
   re-recorded (dated, with its trigger) in `clusters/workload/README.md` "Known limitations".

## Open questions

- **Where the spin-up budget lives.** Options: a committed metrics note under `docs/`, a section in the
  plan, or a generated artifact from the measurement task. To decide in `plan.md`; it must be committed
  and reproducible, not a one-off console reading.
- **Execution environment.** These acceptance criteria require a host with Docker and the full `mise`
  toolchain (talosctl, flux, helm, kubectl); the criteria are verified on that host, not in a
  docs-only or toolchain-less environment.
- **FR5 direction.** Whether a Flux-side config-drift restart mechanism is worth building for a
  single-user v1, or whether the accepted-limitation record is the right v1 answer, is a judgment for
  `plan.md` to frame with options.
