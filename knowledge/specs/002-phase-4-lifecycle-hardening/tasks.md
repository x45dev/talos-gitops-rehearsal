---
id: tasks-002-phase-4-lifecycle-hardening
title: Task list - Phase 4 lifecycle hardening
status: draft
version: 0.2.0
date: 2026-07-25
type: tasks
---

# Tasks: Phase 4 - lifecycle and idempotency hardening

> **Amended 2026-07-25 (v0.2.0)** with `spec.md` v0.2.0: Phase C (T009-T011, spin-up measurement and
> budget) is withdrawn. Task numbers are retained rather than renumbered so existing references stay
> unambiguous. 10 live tasks remain.

**Plan**: `knowledge/specs/002-phase-4-lifecycle-hardening/plan.md`. **HUMAN** marks a step only the owner
may perform - a decision, not a mechanical action; the agent reaches it, stops, and surfaces what is
needed to decide. Tasks run strictly in order (none are parallelizable). Paths are repo-relative. All
execution tasks require a host with Docker and the full `mise` toolchain (talosctl, flux, helm,
kubectl); a docs-only environment can author and review but cannot close them.

## Phase A - End-to-end idempotency (FR1, AC1, AC4)

- [ ] **T001** Audit `.config/mise/tasks/test-talos-spike.toml` task by task
      (`setup`, `provision`, `cilium`, `cloudflare-tunnel-bootstrap`, `flux-bootstrap`,
      `verify-adoption`, `validate`, `verify-phase3`): for each, record what precondition it detects and
      whether a re-run is a genuine no-op. Produce a short findings list of any blind re-apply.
      Treat the `cloudflare-tunnel-bootstrap` unconditional ingress PUT and DNS upsert as the accepted
      idempotent-by-overwrite exception (FR1), not a blind re-apply to fix.
- [ ] **T002** Sleep audit (confirm-and-document; the standalone `sleep 15` was already retired): verify
      every `sleep` in the chain is a retry backoff inside an `until`/`while` loop (currently the
      `sleep 2` calls in `provision`, `validate`, and `verify-phase3`) and that no standalone fixed
      `sleep N` stands in for a precondition wait. If none is found, AC4 is satisfied by recording that
      result; if one is found, convert it to retry-until-condition.
- [ ] **T003** Harden any non-idempotent step found in T001 to detect-and-self-heal (re-run against the
      reached state changes nothing). The accepted external-write exception (T001) is out of scope.
- [ ] **T004** Add an idempotency assertion to the `all` path (or a `test-talos-spike:reconcile-check`
      task): after convergence, a second `all` run reports every `kubectl apply` as `unchanged` (zero
      `configured`/`created`), performs no cluster re-create and no Cilium re-install, exits 0, and
      completes in well under half the cold-run wall time (AC1). Capture both runs' output.
- [ ] **T005** Prove AC1: `all` to convergence, `all` again (no-op), then once more from the same
      converged state. Save the two no-op transcripts for the PR.

## Phase B - Self-verifying zero-residue teardown (FR2, AC2)

- [ ] **T006** Extend `test-talos-spike:teardown` into destroy + verify: after `talosctl cluster
      destroy` and removal of `.kube-*.config`/`.talosconfig`, enumerate residuals and exit non-zero on
      any found. Note: today the task silently `docker rm -f` / `docker network rm`s leftovers; convert
      that auto-remove into inspect-and-fail (or clean-then-verify-clean), so a residual the destroy did
      not remove fails the task loudly instead of being swept before the check fires.
- [ ] **T007** The verify step (T006) must cover: cluster Docker containers, volumes, and the
      `talosctl`-created network; repo-local kube/talos config files; user-global `~/.kube/config` and
      `~/.talos/config` contexts; and the `talosctl` cluster-state directory.
- [ ] **T008** Prove AC2: seed a residual that matches exactly what the verify step inspects (for example
      a Docker network named `$CLUSTER_NAME`, or a `~/.talos/config` context named for the cluster - an
      arbitrarily-named artifact the name-anchored check ignores will not trip it), show the verify step
      fails; run a clean teardown, show it passes. Save both transcripts.

## Phase C - Withdrawn 2026-07-25 (spin-up measurement and budget)

Withdrawn with FR3/FR4/AC3: spin-up time is not a problem in real use, so the measurement harness and
committed budget are scoped out (`spec.md` non-goals, with the revisit trigger).
T009, T010 and T011 are not to be executed; their numbers are retained, not reused.

- [x] **T009-T011** Withdrawn, no action. The withdrawn design is retained in `plan.md` so a future
      revisit is a lookup rather than a redesign.

## Phase D - Day-2 Cilium config-drift gap (FR5, AC5)

- [ ] **T012** **FR5 direction is a HUMAN choice** (build a Flux-reconciled restart-on-drift mechanism
      for agent-level Cilium flag changes vs. re-record the accepted limitation). For a context-free run
      the plan's recommendation is binding: re-record the limitation in `clusters/workload/README.md`
      "Known limitations" with a date and its revisit trigger (the current entry is undated and
      unlabeled). Build the reconciled mechanism only on an explicit owner decision.

## Exit

- [ ] **T013** Verify the four live acceptance criteria in `spec.md` (AC3 is withdrawn); attach the AC1
      no-op transcripts, the AC2 seeded-residual proof, the AC4 sleep-audit result, and the AC5
      decision/record as evidence in the PR description.
- [ ] **T014** Update the working state: `knowledge/progress.md` (Phase 4 under "What works", removing it
      from "What's left") and `knowledge/activeContext.md` (Phase 4 done; name the next focus). Governed
      docs, so a patch version bump each.
