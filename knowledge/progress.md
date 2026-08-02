---
id: progress
title: Progress
status: active
version: 0.1.17
date: 2026-08-02
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
  carries rules 1-7 plus the ADR-0013 rules 8, 9a, 9b and 9c, and passes green on
  all 20 governed documents; the `lint:frontmatter` task hard-fails if the script
  goes missing.
  Rules 8 and 9 were ported early per ADR-0009 and reconciled against the released
  `rka-template` v0.1.0 on 2026-08-02 (below), which is where 9c came from.
- Upstream conventions verified current (2026-07-22 survey): the released
  RKA, `agent-standards`, and `rka-template` conventions are all applied.
- Validator reconciled against the released upstream (2026-08-02), discharging
  ADR-0009's standing obligation.
  Upstream re-cut `rka-template` on 2026-07-31 as a standalone Copier template
  with a fresh single-commit history; its first release, v0.1.0, is the first
  tagged release to ship rules 8 and 9, so the obligation fired.
  The v0.2.0-v0.4.0 tags no longer exist upstream, so this repo's recorded
  v0.4.0 pin had stopped resolving; `context.md` now pins v0.1.0.
  Three divergences were found, all of them the early port lacking upstream
  hardening, and all three were reproduced against this repo's script before
  being fixed:
  - **Rule 9c was absent** (a bundle must hold `spec.md`). An archived bundle of
    `plan.md` + `tasks.md` alone carried no extraction record anywhere and rule
    8's intra-bundle exemption passed it: a clean fail-open, `exit 0`.
  - **Nested bundle documents escaped rule 9a.** The old `[^/]+` role pattern did
    not match `specs/<bundle>/sub/notes.md` at all, so such a file fell through to
    the generic stem convention and never joined its bundle's status set; a nested
    document at `canonical` inside an `active` bundle passed the whole gate.
  - **A trailing slash on the argument disabled rules 9a/9b.** Invoked as
    `knowledge/`, the prefix strip that derives the bundle-relative path failed,
    so no file matched the bundle pattern. The observed symptom is worse than
    upstream's comment suggests: rather than merely missing the violation, the gate
    misdiagnosed it, reporting a mixed-status bundle as two spurious rule-4 stem
    mismatches. Neither call site passes a trailing slash today, so this was
    latent; both call sites are now invocation-invariant.
  Surviving divergences from upstream v0.1.0, all deliberate or cosmetic:
  the yq-missing hint names `mise install` here rather than upstream's
  toolchain-agnostic wording (correct for this repo, which does pin a toolchain);
  this repo's error strings keep their `RFC-003 section 5` / `PRD FR5.2` citations,
  which upstream dropped; 2-space indentation against upstream's 4; and one loop
  variable named `r` rather than `legal`.
  The last divergence, upstream's `tests/validate-frontmatter.bats`, was closed
  the same day (below).
- Validator test suite adopted (2026-08-02): `tests/validate-frontmatter.bats`,
  taken from `rka-template` v0.1.0 per ADR-0012, 26 tests green.
  Until now every rule here had been proven by one-off seeded violation, which
  proves the rule once at the moment it lands and then leaves nothing standing
  behind it; a later edit could quietly reopen any of them.
  The suite builds a throwaway knowledge tree per test and runs the validator end
  to end (find + yq + jq), so it exercises the real toolchain rather than a mock.
  It covers all nine rules, including the three fail-opens closed earlier that day.
  Reindented from upstream's 4 spaces to this repo's 2, the same treatment the
  validator got; a future reconciliation should normalise leading whitespace before
  diffing, and the file's header records the exact command.
  **It runs in CI, not in the pre-commit hook**, and that is a deliberate cost call:
  measured 2026-08-02, `bats tests/validate-frontmatter.bats` takes 1m22s and
  `mise run test` 1m38s (26 tests at ~0.95s a validator run) against ~25s for the
  entire local gate, so putting it in Lefthook would roughly quintuple every commit
  to re-prove rules that only change when the validator changes.
  CI is where this repo's governance enforcement is already binding, and it covers
  the ungated paths (cloud agent sessions, fresh clones) that CI exists for.
  `mise run test` (alias `t`) runs it locally; the task fails loudly rather than
  skipping if `bats` is absent, matching the `lint:frontmatter` two-state rule.
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

**v1 is complete (2026-07-26).** The turnkey payload stands up reproducibly and was
live-verified at Phase 3; the payload itself is the deliverable, and nothing further is
required of v1. What follows is deferred by design, not outstanding work.

- Phase 4 (lifecycle and idempotency hardening): **archived unexecuted 2026-07-26**
  (`knowledge/specs/002-phase-4-lifecycle-hardening/`). Every requirement defended a
  failure mode that had not occurred: spin-up time, non-idempotent re-runs and teardown
  residue have none of them bitten in real use. The bundle's extraction record holds the
  durable findings and what would reopen it.
- Phase 5 (YubiKey hardening) and M-CAPI (real cloud target via Cluster
  API): unscheduled, deferred by design.
- State persistence / DB re-hydration across ephemeral cycles: unresolved
  open question (`context.md`).
- ADR-0010 is the only governed document still at `draft`; promote it to
  `active` once it has seasoned (recorded 2026-07-25).
- Canonical promotion of the `active` ADRs (ADR-0003..0007) is a later gate:
  they should season as `active` through at least one more consuming change
  before an evidence-backed canonical review.
  This condition originally had a second half, seasoning "through the Phase 4
  hardening pass", which was retired on 2026-07-28 because Phase 4 was archived
  unexecuted (2026-07-26) and that trigger can now never fire.
  The surviving condition is unchanged and still untriggered: no consuming
  change has landed against these ADRs since they went `active` on 2026-07-22.
- ~~Reconcile the early-ported validator rules 8/9 against the released
  version~~ **done 2026-08-02** (see "What works"); ADR-0009's standing
  obligation is discharged.
- ~~The validator has no tests of its own.~~ **done 2026-08-02**: upstream's
  `tests/validate-frontmatter.bats` adopted, 26 tests green in CI (see
  "What works").
- **Open question for the maintainer, raised 2026-08-02.** `rka-template` is no
  longer a repo to copy conventions out of by hand: it is now a Copier template
  with a `copier.yml` and an answers file, designed to be applied and re-applied.
  Whether this repo should become a Copier consumer of it - gaining `copier update`
  as the reconciliation mechanism, at the cost of accepting the template's layout
  where this repo has diverged - is an architectural call that has not been made,
  and it is the sort of decision ADR-0012's release-train discipline exists to
  frame. Left open deliberately rather than decided unattended.

## Known issues / limitations

- Single-user by design: Dex's GitHub connector carries no org/team
  restriction; must be restricted before the tunnel ever serves a second
  person (constitution non-goals; `clusters/workload/README.md`).
- Multi-customer / multi-tenant separation has no foundation in this repo;
  treating this repo as "the IDP" overstates its scope (settled by ADR-0007:
  this repo is the single-tenant rehearsal tool, the multi-customer IDP is a
  separate future project).
- Constitution invariants 3 (idempotency bar) and 4 (zero-residue teardown) are
  **stated but unverified**: nothing proves a converged re-run is a no-op, and teardown
  cleans rather than checks. Accepted deliberately on 2026-07-26 (neither has bitten);
  the archived 002 bundle records what would reopen it.
- Devcontainer couples to two sibling repos' churn: the digest-pinned
  `devbase` image (bootstrap-workspace) and the mounted `agent-standards`
  checkout; both update manually.
  Re-pinned 2026-07-28 to `sha256:a9689b11`, replacing the 2026-07-19 pin,
  which predated the 2026-07-22 base rebuild (`2213a77`).
  That rebuild baked the agent-config wiring into the base as
  `link-agent-config`, and `.devcontainer/devcontainer.json` now calls it
  instead of inlining a third copy of the skill list.
  This repo is a **second, cross-repo `devbase` digest pin site**;
  bootstrap-workspace's own re-pin tooling assumes its compose file is the only
  one, so a base rebuild there does not reach this repo (filed upstream as
  `x45dev/bootstrap-workspace#50`).
