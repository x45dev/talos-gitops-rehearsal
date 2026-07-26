---
id: plan-002-phase-4-lifecycle-hardening
title: Implementation plan - Phase 4 lifecycle hardening
status: archived
version: 0.3.0
date: 2026-07-26
type: plan
---

# Implementation Plan: Phase 4 - lifecycle and idempotency hardening

> **Amended 2026-07-25 (v0.2.0, reconciled v0.2.1)** with `spec.md`: Phase C (spin-up measurement and
> budget) is withdrawn. Phases A, B and D stand unchanged. See "Second review" below for what the
> post-amendment gate-3 pass caught.

**Spec**: `knowledge/specs/002-phase-4-lifecycle-hardening/spec.md` | **Branch**: `002-phase-4-lifecycle-hardening`

## Technical context

- **The chain to harden is `.config/mise/tasks/test-talos-spike.toml`.** Its tasks, in dependency
  order, are: `setup` (verify docker/talosctl), `provision` (create the cluster), `cilium` (Helm
  install + agent restart), `cloudflare-tunnel-bootstrap` (create tunnel + inject token secret),
  `flux-bootstrap` (install Flux, inject secrets, hand Cilium day-2 to Git), `verify-adoption`,
  `validate` (the three gates), `verify-phase3`, `teardown`, and the `all` aggregate. Phase 4 hardens
  this chain into a re-runnable, self-verifying lifecycle; it does not add payload components.
- **Idempotency is partially there, not proven end to end.** `provision` and
  `cloudflare-tunnel-bootstrap` already describe themselves as idempotent, `cilium` adopts-in-place
  rather than reinstalling once Flux owns it, and `provision` waits on a real condition
  (`until kubectl get --raw='/readyz'`), not a fixed sleep. What is missing is a proof that the whole
  chain (`all`) re-run against a converged environment is a no-op, and an audit that every step's
  precondition check is genuine rather than assumed. One deliberate exception the audit must not flag:
  `cloudflare-tunnel-bootstrap` does an unconditional ingress-config PUT and DNS upsert with no
  destructive side effect, which is idempotent-by-overwrite and accepted, not a blind re-apply to fix
  (FR1).
- **Sleep audit distinction.** The `sleep 2` calls inside the `until`/`while` loops in `provision`,
  `validate`, and `verify-phase3` are retry backoffs, which are on the right side of the idempotency bar.
  The anti-pattern the bar forbids is a standalone fixed `sleep N` standing in for a precondition (the
  spike's retired `sleep 15`). As of authoring no such standalone sleep remains in the chain, so FR1/AC4
  is a confirm-and-record step, not a rewrite.
- **Teardown already claims residue verification, but auto-removes rather than fails.** `teardown`'s
  description is "Destroy the Talos cluster and verify zero residue", so the gap is completeness and
  enforcement, not a missing task: the check must cover Docker containers, volumes, and the
  `talosctl`-created network, plus repo-local `.kube-*.config`/`.talosconfig` and user-global
  `~/.kube/config` / `~/.talos/config` contexts and the `talosctl` cluster-state directory. Today the
  task silently cleans leftovers (`docker rm -f`, `docker network rm`); hardening converts that silent
  cleaning into inspect-and-fail so a residual the destroy did not remove is surfaced, not swept
  (otherwise the AC2 seeded residual is cleaned before the check can fire).
- **No spin-up measurement exists** (context retained; the workstream is withdrawn). No task times the
  stages to all-`Ready`. Were the revisit trigger ever hit, the shape would be a task stamping stage
  boundaries (cluster create, Cilium ready, Flux ready, payload `Ready`) and emitting a per-stage record.
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
2. Add a dedicated `test-talos-spike:reconcile-check` task (not a change to `all`, whose `run` is only an
   `echo` behind `depends`): after a converged run it re-runs the chain and asserts no resource changes,
   exempting the FR1 external writes and the `git-credentials` secret. No wall-clock assertion - the
   stage timing that would need is the withdrawn workstream. Capture both runs' output.
3. Prove AC1: run `all` to convergence, run it again, show the second run is a no-op; repeat once more
   from the same converged state (twice in a row).

### Phase B - Self-verifying zero-residue teardown (FR2, AC2)

1. Extend `teardown` into a two-step task: destroy, then a residue-verification step that enumerates
   cluster Docker containers, volumes, and networks, repo-local kube/talos config files, user-global
   `~/.kube`/`~/.talos` contexts, and the `talosctl` state directory, and exits non-zero on any residual.
2. Prove AC2 by seeding a residual artifact (for example leave a dangling Docker network or a stale
   kube-context entry) and showing the verification step fails, then that a clean teardown passes.

### Phase C - Withdrawn 2026-07-25 (staged spin-up measurement and budget)

Withdrawn with FR3/FR4/AC3 by the 2026-07-25 amendment: spin-up time has not been painful in daily use,
so the measurement harness and committed budget are scoped out (`spec.md` non-goals, with the revisit
trigger). The phase letter is retained rather than reused so Phase D's references stay unambiguous.
Nothing in this phase is required for done.

### Phase D - Day-2 Cilium config-drift gap (FR5, AC5)

1. Decide the direction (see open question below) and either implement a Flux-reconciled restart-on-drift
   mechanism for agent-level Cilium flag changes, or re-record the limitation in
   `clusters/workload/README.md` "Known limitations" with a date and its revisit trigger.

## Decisions on the spec's open questions

- **Where the spin-up budget lives**: moot as of the 2026-07-25 amendment (the budget is scoped out).
  Retained for the revisit: the recommendation was a committed
  `docs/reviews/phase-4-spinup-budget-<date>.md` emitted by the measurement task, mirroring how
  `docs/reviews/` already holds point-in-time evidence artifacts, so it is committed and reproducible
  rather than a console reading, and is not governed knowledge.
- **FR5 direction**: recommend the accepted-limitation record for v1. A Flux-side config-drift restart is
  real engineering for a single-user rehearsal tool whose Cilium values change rarely; the honest dated
  limitation plus the imperative bootstrap restart is proportionate, and building the reconciled
  mechanism is better deferred to when a day-2 Cilium value actually needs to change under Flux. The
  final call is recorded when Phase D lands.

## Risks and mitigations

- **Teardown false-negatives**: a residue check that greps too narrowly can pass while leaving cruft.
  Mitigation: the seeded-residual test (AC2) proves the check actually bites, exactly as the governance
  spec used a seeded frontmatter violation.
- **Descope regret**: withdrawing the measurement workstream means a future spin-up regression is noticed
  by feel rather than caught by a number. Mitigation: accepted deliberately - the revisit trigger is
  recorded in `spec.md`'s non-goals, and the withdrawn design is retained in this plan so rebuilding it is
  a lookup, not a redesign.
- **Toolchain requirement**: none of these acceptance criteria can be verified without the cluster
  toolchain. Mitigation: this plan and its tasks are executed on a Docker + `mise` host; a docs-only
  session can author and review them but not close them.

## Definition of done

The four live acceptance criteria in `spec.md` verified on a toolchain-equipped host: the
idempotent-re-run transcript (AC1), the seeded-residual teardown proof (AC2), the no-standalone-sleep
audit (AC4), and the resolved-or-recorded day-2 Cilium gap (AC5).
AC3 is withdrawn (2026-07-25 amendment) and is not part of done.
Done also requires the owner decision on the orphaned spin-up commitment (T015, HUMAN) and the bundle's
retirement with its extraction record (T016); the latter is enforced mechanically, since rules 9b and 8
fail the commit otherwise.

## Pre-implementation review (gate 3)

A fresh-context adversarial review of the trio was run on 2026-07-22 against the executable-without-guessing
contract (gate 3 of `docs/how-to-spec-driven-work.md` in the external `agent-standards` repository, not
a path in this repo), prompted to refute.
It confirmed the plan's grounding facts (every cited `test-talos-spike:*` task exists; the `sleep` calls
are all retry-loop backoffs; `teardown` already claims residue verification; the FR5 README target
exists) and surfaced the defects reconciled into this bundle: the two owner-only decision points then carried
HUMAN markers (`tasks.md` T011 lever 3, T012 FR5 direction - T011 was later withdrawn by the 2026-07-25
amendment and its sign-off re-established as T015), AC1 was made mechanically checkable, the
FR1-versus-unconditional-Cloudflare-PUT collision is resolved as an accepted exception, and the
teardown auto-remove trap and seeded-residual matching (T006/T008) are called out.
Framing review (gate 1, zoom-out) was deliberately skipped at that point: Phase 4 read as
obviously-scoped hardening whose direction was fixed by the PRD and constitution.
That judgement was partly wrong, and the 2026-07-25 amendment is the correction: asking whether the
spin-up workstream was solving a real problem was exactly a framing question, and the answer (measured
against real use, it was not) removed two of the five requirements.

### Second review, on the amended bundle (2026-07-25)

The descope changed the contract, so gate 3 was re-run on v0.2.0. It returned six blockers and the
bundle was **not** executable as written; v0.2.1 reconciles them. What it caught, recorded because the
defects are instructive rather than clerical:

1. **The exit path failed the repo's own gate.** Ticking every task would have made `tasks.md` fully
   checked, firing validator rule 9b (bundle must be `archived`), which would then fail rule 8 (no
   `Extraction record` in `spec.md`) - and CI runs that validator. The plan had no instruction to
   resolve it. Fixed by T016, which retires the bundle in the same change that ticks the last task.
2. **The descope deleted a human sign-off.** T011's lever 3 was the only HUMAN-marked hook for
   "renegotiate the PRD metric explicitly, never silently missing it". Withdrawing T011 removed it, so
   the orphaned PRD Section 7 / constitution commitment had no owner decision attached. Re-established
   as T015.
3. **`spec.md` and `tasks.md` contradicted each other** on whether the withdrawn measurement work could
   still be built ("welcome" versus "not to be executed"), and on whether T004's wall-time comparison was
   binding or corroborating. Both reconciled; the timing clause is dropped, since the stage timing it
   needs is the withdrawn workstream.
4. **Three passages still asserted the withdrawn scope** as live (US3, a "Why" bullet, and an open
   question instructing `plan.md` to decide where the budget lives). Marked withdrawn or moot.
5. **The stated task count was wrong** (10 claimed, 11 actual at the time).
6. **AC1 was not reliably satisfiable**: the `git-credentials` secret rebuilds `known_hosts` from a live
   `api.github.com/meta` fetch, so a GitHub key rotation reports `configured` with no defect present.
   Added to AC1's exemptions.

It also found that the amendment's own justification was overstated in `spec.md` while this plan's
"Descope regret" risk was honest about the same trade-off; `spec.md` now matches the plan rather than
the other way round.
