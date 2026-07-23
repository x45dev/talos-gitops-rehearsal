---
id: tasks-002-phase-4-lifecycle-hardening
title: Task list - Phase 4 lifecycle hardening
status: draft
version: 0.1.0
date: 2026-07-22
type: tasks
---

# Tasks: Phase 4 - lifecycle, idempotency, and metrics hardening

**Plan**: `docs/specs/002-phase-4-lifecycle-hardening/plan.md`. `[P]` = parallelizable with the previous
task. Paths are repo-relative. All execution tasks require a host with Docker and the full `mise`
toolchain (talosctl, flux, helm, kubectl); a docs-only environment can author and review but cannot
close them.

## Phase A - End-to-end idempotency (FR1, AC1, AC4)

- [ ] **T001** Audit `.config/mise/tasks/test-talos-spike.toml` task by task
      (`setup`, `provision`, `cilium`, `cloudflare-tunnel-bootstrap`, `flux-bootstrap`,
      `verify-adoption`, `validate`, `verify-phase3`): for each, record what precondition it detects and
      whether a re-run is a genuine no-op. Produce a short findings list of any blind re-apply.
- [ ] **T002** Sleep audit: confirm every `sleep` is a retry backoff inside an `until`/`while` condition
      loop, and that no standalone fixed `sleep N` stands in for a precondition wait. Fix any that do by
      converting to retry-until-condition (satisfies AC4).
- [ ] **T003** Harden any non-idempotent step found in T001 to detect-and-self-heal (re-run against the
      reached state changes nothing).
- [ ] **T004** Add an idempotency assertion to the `all` path (or a `test-talos-spike:reconcile-check`
      task): after convergence, a second `all` run reports no resource changes and finishes measurably
      faster. Capture both runs' output.
- [ ] **T005** Prove AC1: `all` to convergence, `all` again (no-op), then once more from the same
      converged state. Save the two no-op transcripts for the PR.

## Phase B - Self-verifying zero-residue teardown (FR2, AC2)

- [ ] **T006** Extend `test-talos-spike:teardown` into destroy + verify: after `talosctl cluster
      destroy` and removal of `.kube-*.config`/`.talosconfig`, enumerate residuals and exit non-zero on
      any found.
- [ ] **T007** [P] The verify step must cover: cluster Docker containers, volumes, and the
      `talosctl`-created network; repo-local kube/talos config files; user-global `~/.kube/config` and
      `~/.talos/config` contexts; and the `talosctl` cluster-state directory.
- [ ] **T008** Prove AC2: seed a residual (for example a dangling Docker network or a stale kube-context
      entry), show the verify step fails; run a clean teardown, show it passes. Save both transcripts.

## Phase C - Staged spin-up measurement and budget (FR3, FR4, AC3)

- [ ] **T009** Add a measurement task that stamps stage boundaries (cluster create, Cilium ready, Flux
      ready, payload all-`Ready`) and emits a per-stage timing record with a total, reproducible from a
      clean `teardown`.
- [ ] **T010** Run the measurement cold (from clean `teardown`) and commit the record as
      `docs/reviews/phase-4-spinup-budget-<date>.md`, noting the image-cache assumption alongside the
      numbers.
- [ ] **T011** If the total exceeds 10 minutes, apply the FR4 levers in order and record which was used:
      (1) host-side pull-through registry mirror via `talosctl cluster create` registry-mirror flags,
      (2) relax `dependsOn` chains where safe, (3) last resort, renegotiate the PRD metric explicitly.
      If under target, record that no lever was needed.

## Phase D - Day-2 Cilium config-drift gap (FR5, AC5)

- [ ] **T012** Record the FR5 direction decision (plan recommends the accepted-limitation record for v1).
      Then either implement a Flux-reconciled restart-on-drift mechanism for agent-level Cilium flag
      changes, or re-record the limitation in `clusters/workload/README.md` "Known limitations" with a
      date and its revisit trigger.

## Exit

- [ ] **T013** Verify all five acceptance criteria in `spec.md`; attach the AC1 no-op transcripts, the
      AC2 seeded-residual proof, the committed spin-up budget (AC3), the AC4 sleep-audit result, and the
      AC5 decision/record as evidence in the PR description.
- [ ] **T014** Update the working state: `knowledge/progress.md` (Phase 4 under "What works", removing it
      from "What's left") and `knowledge/activeContext.md` (Phase 4 done; name the next focus). Governed
      docs, so a patch version bump each.
