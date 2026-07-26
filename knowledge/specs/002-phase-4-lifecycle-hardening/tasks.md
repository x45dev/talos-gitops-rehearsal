---
id: tasks-002-phase-4-lifecycle-hardening
title: Task list - Phase 4 lifecycle hardening
status: draft
version: 0.2.2
date: 2026-07-25
type: tasks
---

# Tasks: Phase 4 - lifecycle and idempotency hardening

> **Amended 2026-07-25 (v0.2.0)** with `spec.md` v0.2.0: Phase C (T009-T011, spin-up measurement and
> budget) is withdrawn. Task numbers are retained rather than renumbered so existing references stay
> unambiguous. 13 live tasks remain: T001-T008 and T012-T016.

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
- [ ] **T004** Add a new `["test-talos-spike:reconcile-check"]` task (not a change to `all`, whose `run`
      is only an `echo` behind `depends`): after convergence it re-runs the chain and asserts every
      `kubectl apply` reports `unchanged` with zero `configured`/`created`, no cluster re-create, and no
      Cilium re-install, exiting non-zero otherwise (AC1). Exempt the FR1 external writes and the
      `git-credentials` secret (its `known_hosts` comes from a live `api.github.com/meta` fetch).
      Do not gate on wall-clock time: the stage timing that would need is the withdrawn workstream.
      Capture both runs' output.
- [ ] **T005** Prove AC1: `all` to convergence, `all` again (no-op), then once more from the same
      converged state. Save the two no-op transcripts for the PR.

## Phase B - Self-verifying zero-residue teardown (FR2, AC2)

Note: `teardown` has no `depends` and is **not** reachable from `all`, so every task below invokes
`mise run test-talos-spike:teardown` explicitly.

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

T009, T010 and T011 are deliberately written as a plain bullet with no checkbox, not as a ticked task.
Validator rule 9b counts only checkbox lines, so a withdrawn task left as `- [ ]` would keep the bundle
permanently "incomplete" and stop 9b ever forcing archival - the exact shipped-but-unretired failure
ADR-0013 exists to catch - while marking it `- [x]` would falsely read as done. A plain bullet is
neither. Do not convert this line into a checkbox.

- ~~**T009-T011**~~ Withdrawn 2026-07-25. The withdrawn design is retained in `plan.md` so a future
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
- [ ] **T014** Update the working state and every document this feature falsifies:
      `knowledge/progress.md` (Phase 4 under "What works", removed from "What's left"),
      `knowledge/activeContext.md` (Phase 4 done; name the next focus),
      `knowledge/constitution.md` (its phased-status line still reads "Phase 4
      (lifecycle/idempotency/metrics hardening) has not started"), and `knowledge/index.md` (its 002
      entries still describe the withdrawn spin-up scope and say "markers" plural).
      All governed, so a patch version bump each; `index.md` carries no frontmatter.
- [x] **T015** **HUMAN - owner decision.** Resolved 2026-07-25, out of phase order: this task depends
      only on the descope, not on Phase 4 execution, so it was closed early.
      Recorded as `knowledge/adr/ADR-0010.md` (`adr_status: accepted`): the under-ten-minute metric
      stands unchanged but is deliberately uninstrumented in v1, and the three documents that named a
      carrier (PRD Section 7, PLAN Phase 4 item 3, the constitution's definition of done) now point at
      the ADR instead. Provenance: the substance is the maintainer's (they reported spin-up is not
      painful and directed the descope, then directed this task); the choice between the two options
      below was the agent's, taken on that instruction and reversible.
      Original wording follows.
      **HUMAN - owner decision, do not perform autonomously.** The descope leaves PRD Section 7
      and the constitution's definition-of-done spin-up metric carried by nothing: PRD Section 7 names
      the plan's Phase 4 as the budget's carrier and forbids the metric being "silently missed", and
      withdrawing FR3/FR4 produces exactly that state. This is the sign-off that was lost when T011
      (whose lever 3 was "renegotiate the PRD metric explicitly") was withdrawn.
      Present the owner with the two options and stop: (a) amend `docs/planning/PRD.md` Section 7 and
      `docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` Phase 4 item 3 so neither claims a carrier
      that no longer exists, or (b) record an ADR accepting a deliberately uninstrumented metric with its
      revisit trigger. Do not choose on the owner's behalf.
- [ ] **T016** Retire the bundle in the same change that ticks the last task: write the
      `## Extraction record` section in `spec.md` (durable knowledge from this feature, per RFC-002
      section 3) and set `status: archived` on all three bundle files with a minor version bump.
      This is not optional bookkeeping: once every checkbox above is ticked, validator rule 9b fails the
      commit until the bundle is `archived`, and rule 8 then fails it until the extraction record exists.
      CI (`.github/workflows/ci.yml`) runs the same validator, so skipping this blocks the merge.
