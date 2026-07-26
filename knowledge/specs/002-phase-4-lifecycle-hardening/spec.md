---
id: spec-002-phase-4-lifecycle-hardening
title: Phase 4 - lifecycle and idempotency hardening
status: archived
version: 0.3.0
date: 2026-07-26
type: spec
---

# Feature Specification: Phase 4 - lifecycle and idempotency hardening

> **Archived 2026-07-26 without being executed, maintainer decision.** The surviving requirements
> defended failure modes that have not occurred: asked directly, the maintainer reported that neither
> non-idempotent re-runs nor teardown residue has bitten in real use.
> That is the same test that withdrew FR3/FR4 on 2026-07-25, applied to the rest of the bundle.
> The invariants remain stated in the constitution and remain unverified; see the Extraction record at
> the end of this file for what that costs and what would reopen it.
>
> **Amended 2026-07-25 (v0.2.0, reconciled v0.2.1), maintainer decision.** The spin-up measurement and budget workstream
> (FR3, FR4, AC3) is withdrawn to non-goals: the maintainer reports spin-up time has not been painful in
> daily use, so building the harness was judged not worth its cost right now.
> That report is an impression, not a measurement, and the trade-off is real: see `plan.md`'s
> "Descope regret" risk, and the orphaned-commitment note in the non-goal below.
> What remains is the half that enforces constitution invariants 3 and 4, which nothing currently
> proves: end-to-end idempotency (FR1), self-verifying zero-residue teardown (FR2), and the day-2 Cilium
> record (FR5).
> Withdrawn identifiers are retained rather than renumbered so existing references stay unambiguous.
> The title dropped "metrics" to match.

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
- **Spin-up time is unmeasured against its target** (context only; withdrawn 2026-07-25, see non-goals).
  PRD Success Metric 1 is under 10 minutes from `mise` command to every payload
  `HelmRelease`/`Kustomization` reporting `Ready`. Only a Phase 0 baseline exists (cluster + Cilium +
  gates, ~5-6 min); the full Flux-driven payload has not been measured. This feature no longer closes
  that gap.

Until this feature lands, the environment works but its lifecycle guarantees rest on assertion rather
than on a re-runnable, self-verifying pipeline.

## User stories

- **US1 - Developer, safe re-run**: As the developer, re-running the bootstrap task against an
  already-converged environment is a no-op that changes nothing and completes fast, so I can re-invoke it
  freely without fear of duplicated work, races, or drift.
- **US2 - Developer, clean teardown**: As the developer, teardown destroys the cluster and then proves it
  left zero residue (containers, volumes, networks, and user-global kube/talos config), so a later
  `setup` starts from a genuinely clean slate and my workstation does not accumulate cruft across cycles.
- **US3 - Withdrawn 2026-07-25** (maintainer, measured spin-up). The story it served - a regression being
  visible as data rather than a vague slowdown - is genuinely given up by this descope, not satisfied
  another way. Retained here, struck, so the cost stays visible.

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
- **FR3 - Withdrawn 2026-07-25** (staged spin-up measurement and recorded budget).
  Moved to non-goals; see "Spin-up measurement and budget" below for the reason and the revisit trigger.
  The number is retained rather than reused, so existing references stay unambiguous.
- **FR4 - Withdrawn 2026-07-25** (budget-overrun levers). Moved to non-goals with FR3.
- **FR5 - Close or record the day-2 Cilium config-drift gap.** The known limitation that agent-level
  Cilium flag changes have no Flux-side equivalent of the bootstrap task's unconditional `DaemonSet`
  restart is either closed (a reconciled mechanism) or re-recorded as an accepted, dated limitation with
  its trigger, so the idempotency story does not silently exclude day-2 Cilium changes.

## Non-goals (scoped out, with reasons)

- **Spin-up measurement and budget (former FR3/FR4), scoped out 2026-07-25.** The maintainer reports
  that spin-up time has not been painful in real daily use, so the harness and committed budget are
  judged not worth their cost right now.
  That is a user's impression rather than a measurement, and it is weighed against the 2026-07-05 plan's
  own assumption (untested) that the Flux-sequenced payload would be the blowout stage: neither side of
  that call rests on data, which is precisely why the decision is the maintainer's and is recorded here.
  The PRD's under-ten-minute success metric is not renegotiated by this spec, but it is left
  uninstrumented, so no one can say whether it is met.
  That is a weaker position than PRD Section 7 intends, and it is named rather than glossed (see the
  orphaned-commitment note below).
  **Revisit trigger:** a spin-up that becomes noticeable in daily use, a payload component whose
  readiness visibly dominates, or a cloud (CAPA) milestone where the timing carries over.
  The measurement task is not to be built as part of this feature; building it needs an owner decision
  (see T015), so `spec.md` and `tasks.md` agree rather than leaving an agent to choose.

  **Orphaned commitment, stated plainly.** `docs/planning/PRD.md` Section 7 names *the plan's Phase 4* as
  the carrier of the per-stage budget and says the metric is "renegotiated explicitly (scope or number),
  never silently missed"; `docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` Phase 4 item 3 assigns
  the same work; and `knowledge/constitution.md`'s effective definition of done lists the under-ten-minute
  metric. Withdrawing the workstream leaves that commitment carried by nothing, which is the state PRD
  Section 7 forbids. This spec does not resolve that on the maintainer's behalf: T015 is a HUMAN task to
  decide between amending the PRD/PLAN or recording an ADR that accepts an uninstrumented metric.
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
   writes (FR1) are exempt. Also exempt: the `git-credentials` secret, whose `known_hosts` is rebuilt from a
   live `api.github.com/meta` fetch on every run, so GitHub rotating or reordering its published keys can
   report `configured` with no idempotency defect present. Proven twice in a row, both no-op transcripts
   saved. (Wall-time comparison is deliberately not part of this criterion: the stage timing it would
   need is the withdrawn workstream.)
2. **Zero-residue teardown, verified**: after `teardown`, an automated check reports zero cluster Docker
   containers/volumes/networks and zero config residue in repo-local and user-global kube/talos config
   and the `talosctl` state directory; a deliberately seeded residual artifact makes the check fail.
3. **Withdrawn 2026-07-25** (recorded spin-up budget). Withdrawn with FR3/FR4; the number is retained
   rather than reused so existing references stay unambiguous. Nothing is required for this criterion.
4. **No sub-idempotency-bar sleeps**: a scan of the bootstrap tasks shows no fixed-duration sleep standing
   in for a precondition check; each wait is a retry-until-condition loop.
5. **Day-2 Cilium gap resolved on the record**: FR5 is either implemented or the limitation is
   re-recorded (dated, with its trigger) in `clusters/workload/README.md` "Known limitations".

## Open questions

- **Where the spin-up budget lives - moot 2026-07-25.** Resolved by withdrawal, not by an answer: there
  is no budget to place. `plan.md` retains the shape that was recommended, for the revisit.
- **Execution environment.** These acceptance criteria require a host with Docker and the full `mise`
  toolchain (talosctl, flux, helm, kubectl); the criteria are verified on that host, not in a
  docs-only or toolchain-less environment.
- **FR5 direction.** Whether a Flux-side config-drift restart mechanism is worth building for a
  single-user v1, or whether the accepted-limitation record is the right v1 answer, is a judgment for
  `plan.md` to frame with options.

## Extraction record

Recorded 2026-07-26, on archival without execution.

**Why it was archived rather than run.** Every requirement in this bundle defended a failure mode that
has not occurred. FR3/FR4 (spin-up budget) went first, on 2026-07-25, because spin-up time was not
painful in daily use. FR1 (end-to-end idempotency) and FR2 (zero-residue teardown) followed on
2026-07-26 for the same reason: asked directly, the maintainer reported neither has bitten. Executing
the bundle would have spent a cluster-equipped session hardening against the hypothetical.

**What this costs, stated plainly.** Constitution invariants 3 (the idempotency bar) and 4
(deterministic, zero-residue teardown) remain *asserted and unverified*. Nothing proves a converged
re-run is a no-op, and teardown cleans rather than checks. This is recorded as a known limitation in
`knowledge/progress.md` rather than quietly dropped.

**Durable knowledge worth keeping** (verified against the tree while this bundle was authored):

- `cloudflare-tunnel-bootstrap` performs an unconditional ingress-config PUT and DNS upsert. This is
  idempotent-by-overwrite with no destructive side effect and is deliberate, not a defect - any future
  idempotency audit should treat it as an accepted exception rather than "fix" it.
- The `git-credentials` secret rebuilds `known_hosts` from a live `api.github.com/meta` fetch on every
  run, so a GitHub key rotation or reordering makes `kubectl apply` report `configured` with no
  idempotency defect present. Any future no-op assertion must exempt it.
- `teardown` silently `docker rm -f`/`docker network rm`s leftovers rather than failing on them, and is
  not reachable from the `all` aggregate (it has no `depends`), so it must be invoked explicitly.
- The idempotency bar distinguishes a retry backoff inside an `until`/`while` condition loop (fine, and
  what the chain uses) from a standalone fixed `sleep N` standing in for a precondition (forbidden). No
  standalone sleep remained in the chain as of 2026-07-25.
- Method note: two fresh-context adversarial reviews of this bundle each returned blockers, including
  an exit path that would have failed the repo's own validator and a descope that silently deleted a
  human sign-off. The reviews were worth more than the feature.

**What would reopen this.** A non-idempotent re-run or teardown residue actually biting; a second person
using the tool, where "it has not bitten me" stops being sufficient evidence; or the substrate changing
(the parked LXC/micro-cluster direction), which would invalidate the teardown and idempotency analysis
above since it is specific to the Docker provisioner.

Superseded by: nothing. v1 is complete; no successor spec is planned.
