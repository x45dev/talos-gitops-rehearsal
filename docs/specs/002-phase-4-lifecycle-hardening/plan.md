---
id: plan-002-phase-4-lifecycle-hardening
title: Implementation plan - Phase 4 lifecycle hardening
status: draft
version: 0.1.0
date: 2026-07-22
type: plan
---

# Implementation Plan: Phase 4 - lifecycle, idempotency, and metrics hardening

**Spec**: `docs/specs/002-phase-4-lifecycle-hardening/spec.md` | **Branch**: `002-phase-4-lifecycle-hardening`

## Technical context

- **The chain to harden is `.config/mise/tasks/test-talos-spike.toml`.** Its tasks, in dependency
  order, are: `setup` (verify docker/talosctl), `provision` (create the cluster), `cilium` (Helm
  install + agent restart), `cloudflare-tunnel-bootstrap` (create tunnel + inject token secret),
  `flux-bootstrap` (install Flux, inject secrets, hand Cilium day-2 to Git), `verify-adoption`,
  `validate` (the three gates), `verify-phase3`, `teardown`, and the `all` aggregate. Phase 4 hardens
  this chain into a re-runnable, self-verifying, measured lifecycle; it does not add payload components.
- **Idempotency is partially there, not proven end to end.** `provision`, `cilium`, and
  `cloudflare-tunnel-bootstrap` already describe themselves as idempotent, and `provision` waits on a
  real condition (`until kubectl get --raw='/readyz'`), not a fixed sleep. What is missing is a proof
  that the whole chain (`all`) re-run against a converged environment is a no-op, and an audit that every
  step's precondition check is genuine rather than assumed.
- **Sleep audit distinction.** The `sleep 2` calls inside the `until` loops in `provision` and `validate`
  are retry backoffs, which are on the right side of the idempotency bar. The anti-pattern the bar
  forbids is a standalone fixed `sleep N` standing in for a precondition (the spike's retired
  `sleep 15`). FR1/AC4 is satisfied by confirming no such standalone sleep remains, not by removing
  retry-loop backoffs.
- **Teardown already claims residue verification.** `teardown`'s description is "Destroy the Talos
  cluster and verify zero residue", so the gap is completeness and enforcement, not a missing task: the
  check must cover Docker containers, volumes, and the `talosctl`-created network, plus repo-local
  `.kube-*.config`/`.talosconfig` and user-global `~/.kube/config` / `~/.talos/config` contexts and the
  `talosctl` cluster-state directory, and it must fail loudly on any residual rather than warn.
- **No spin-up measurement exists.** There is no task that times the stages to all-`Ready`. FR3 needs a
  measurement task that stamps stage boundaries (cluster create, Cilium ready, Flux ready, payload
  `Ready`) and emits a per-stage record; the plan below chooses where that record is committed.
- **The day-2 Cilium gap is real and located.** `cilium` restarts the agent `DaemonSet` unconditionally
  after install/upgrade because Helm value changes update the ConfigMap without rolling the agents; once
  Flux owns Cilium day-2, there is no Flux-side equivalent. FR5 either builds a reconciled equivalent or
  re-records the accepted limitation with its trigger in `clusters/workload/README.md`.
- **Constitution check.** This is cluster-lifecycle work, so the three engineering gates
  (`knowledge/constitution.md` definition of done) and the idempotency and teardown invariants (3 and 4)
  all apply, and verification requires a host with Docker and the full `mise` toolchain
  (talosctl, flux, helm, kubectl). It cannot be verified in a docs-only or toolchain-less environment;
  the acceptance criteria are checked on that host.

## Phases

### Phase A - End-to-end idempotency (FR1, AC1, AC4)

1. Audit each `test-talos-spike:*` task for a genuine precondition check; list any step that re-applies
   blindly or waits on a standalone fixed sleep, and convert it to detect-and-self-heal or
   retry-until-condition.
2. Add an idempotency assertion to the `all` path (or a dedicated `reconcile-check` task): after a
   converged run, a second run reports no resource changes and completes measurably faster; capture both
   runs' output.
3. Prove AC1: run `all` to convergence, run it again, show the second run is a no-op; repeat once more
   from the same converged state (twice in a row).

### Phase B - Self-verifying zero-residue teardown (FR2, AC2)

1. Extend `teardown` into a two-step task: destroy, then a residue-verification step that enumerates
   cluster Docker containers, volumes, and networks, repo-local kube/talos config files, user-global
   `~/.kube`/`~/.talos` contexts, and the `talosctl` state directory, and exits non-zero on any residual.
2. Prove AC2 by seeding a residual artifact (for example leave a dangling Docker network or a stale
   kube-context entry) and showing the verification step fails, then that a clean teardown passes.

### Phase C - Staged spin-up measurement and budget (FR3, FR4, AC3)

1. Add a measurement task that stamps stage boundaries (cluster create, Cilium ready, Flux ready, payload
   all-`Ready`) and emits a per-stage timing record with a total, reproducible from a clean `teardown`.
2. Commit the record as the budget baseline (location decided below), measured on the reference host.
3. If the total exceeds 10 minutes, apply the FR4 levers in order and record which was used: a host-side
   pull-through registry mirror via `talosctl cluster create` registry-mirror flags first, then relaxing
   `dependsOn` chains where safe, and only last renegotiating the PRD metric explicitly.

### Phase D - Day-2 Cilium config-drift gap (FR5, AC5)

1. Decide the direction (see open question below) and either implement a Flux-reconciled restart-on-drift
   mechanism for agent-level Cilium flag changes, or re-record the limitation in
   `clusters/workload/README.md` "Known limitations" with a date and its revisit trigger.

## Decisions on the spec's open questions

- **Where the spin-up budget lives**: recommend a committed `docs/reviews/phase-4-spinup-budget-<date>.md`
  emitted by the measurement task, mirroring how `docs/reviews/` already holds point-in-time evidence
  artifacts. It is committed and reproducible, not a console reading, and it is not governed knowledge
  (it is a measurement record, like the promotion-evidence files).
- **FR5 direction**: recommend the accepted-limitation record for v1. A Flux-side config-drift restart is
  real engineering for a single-user rehearsal tool whose Cilium values change rarely; the honest dated
  limitation plus the imperative bootstrap restart is proportionate, and building the reconciled
  mechanism is better deferred to when a day-2 Cilium value actually needs to change under Flux. The
  final call is recorded when Phase D lands.

## Risks and mitigations

- **Measurement variance**: image-pull times dominate and vary with cache state, so a single reading can
  mislead. Mitigation: measure from a clean `teardown` (cold), record the cache assumption alongside the
  numbers, and treat the budget as a baseline with a stated tolerance, not a hard pass/fail on one run.
- **Teardown false-negatives**: a residue check that greps too narrowly can pass while leaving cruft.
  Mitigation: the seeded-residual test (AC2) proves the check actually bites, exactly as the governance
  spec used a seeded frontmatter violation.
- **Registry-mirror lever complexity**: the mirror is the first lever but adds host-side setup. Mitigation:
  apply it only if the measured total exceeds the target, and record whether it was needed rather than
  building it pre-emptively.
- **Toolchain requirement**: none of these acceptance criteria can be verified without the cluster
  toolchain. Mitigation: this plan and its tasks are executed on a Docker + `mise` host; a docs-only
  session can author and review them but not close them.

## Definition of done

All five acceptance criteria in `spec.md` verified on a toolchain-equipped host: the idempotent-re-run
transcript (AC1), the seeded-residual teardown proof (AC2), the committed per-stage spin-up budget (AC3),
the no-standalone-sleep audit (AC4), and the resolved-or-recorded day-2 Cilium gap (AC5). The measurement
record and any applied lever are committed with the change.
