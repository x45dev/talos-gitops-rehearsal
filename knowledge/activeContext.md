---
id: activeContext
title: Active Context
status: active
version: 0.2.2
date: 2026-08-02
type: context
---

# Active Context

Current focus, decisions in flight, and the immediate to-do.
Created by the 2026-07-19 cross-repo ecosystem review (full report:
`repository-knowledge-architecture` `docs/reviews/ecosystem-review-2026-07-19.md`);
this repo previously had no working-state pair, so live state could only be
read out of `docs/planning/PLAN-*.md`.

## Current focus

Phases 0-3 are done and live-verified (2026-07-12): Talos provisioning with
Cilium, the `clusters/workload/` Flux loop, and the full turnkey payload
(cert-manager + local Root CA, Dex GitHub OIDC, Cloudflare Tunnel).
**v1 is complete as of 2026-07-26.** The turnkey payload is the deliverable and it
stands up reproducibly; Phase 4 was archived unexecuted because every requirement it
carried defended a failure mode that had not occurred.
No execution work is outstanding. Phase 5 (YubiKey) and M-CAPI stay deferred by design,
and the LXC/micro-cluster substrate question is parked until a real need arrives.

## Decisions settled by ADR-0007 (accepted 2026-07-22)

- **Scope identity (ecosystem review R6).** Decided: this repo is a single-user
  single-cluster local GitOps rehearsal tool; the multi-customer ephemeral IDP
  is a separate future project (own PRD) that consumes this repo's verified
  patterns, rather than living implicitly in this repo's framing.
  Recorded in `knowledge/adr/ADR-0007.md` (now `adr_status: accepted`).
- **Repo name.** `kind` was removed entirely by ADR-0001, so `kind-talos-gitops`
  is a stale artifact.
  Recorded-deferred in ADR-0007: fold the rename into the next change that
  already touches the Flux `GitRepository` URL
  (`clusters/workload/flux-system/gotk-sync.yaml`), rather than churning a
  running cluster's Flux source for no functional gain.

## Upstream tracking (2026-07-22 survey)

Surveyed the three upstreams: `rka-template` at its latest tag v0.4.0, the RKA
reference repo and `agent-standards` at `main`.
The most recent released conventions are already applied here: the six-field
frontmatter schema, `adr_status`, the rule-current validator (rules 1-7), and
`hide = true` on the aggregate lint tasks.
`agent-standards` adds nothing to pull: its ADR-0005 declines to enforce a spec
lifecycle outside RKA-adopted repos, and its agent entry points are user-level
config, not repo-distributed.

**Update 2026-07-24: RKA ADR-0013 adopted early, by maintainer decision.**
The survey originally deferred it, because rules 8 and 9 live only in the RKA
reference repo's `main` and have not shipped in `rka-template` v0.4.0, so
ADR-0012 (consume at tagged releases, never HEAD) argued for waiting.
The maintainer directed adoption now; this repo was the motivating example for
the upstream rules, and waiting left its own failure mode ungated.
Recorded as a scoped exception in `knowledge/adr/ADR-0009.md`: rules 8, 9a, and
9b plus spec-bundle id handling are ported into
`scripts/validate-frontmatter.sh`, and both bundles now live under
`knowledge/specs/` (`docs/specs/` is gone).
ADR-0012 still governs every other upstream convention.

**Update 2026-08-02: the reconciliation obligation is discharged.**
Upstream re-cut `rka-template` on 2026-07-31 as a standalone Copier template with
a fresh single-commit history, and its first release v0.1.0 is the first tagged
release to ship rules 8 and 9.
The v0.4.0 pin recorded above therefore no longer resolves: v0.2.0-v0.4.0 are gone
upstream, and `knowledge/context.md` now pins v0.1.0.
Reconciling found three fail-opens the early port lacked, each reproduced against
this repo's script before being fixed; the full divergence record is in
`knowledge/progress.md`.

## Next steps (to-do)

- [x] **Restore `scripts/validate-frontmatter.sh`** - done: the validator is
      present and rule-current with `rka-template` v0.4.0 (rules 1-7), and the
      `lint:frontmatter` gate hard-fails when it is missing rather than
      no-opping.
      Confirmed green; now extended with rules 8/9 (19 files, 2026-07-24).
- [x] **Adopt release-pinned upstream tracking** (ecosystem review R1):
      recorded in `knowledge/context.md` (System patterns) and in the survey
      note above.
      Pins verified 2026-07-22: `rka-template` v0.4.0; RKA reference and
      `agent-standards` consumed only through tagged releases per ADR-0012,
      never at upstream HEAD.
- [x] **Progress the `draft` governance backlog** (2026-07-22): ADR-0003 to
      ADR-0006 promoted `draft -> active` (evidence artifact adjudicated and
      recorded), ADR-0007 accepted and `active`, and `context.md` plus the
      constitution promoted to `active` (its definition-of-done synthesis
      confirmed). The PRD is kept unmanaged as an extraction source per ADR-0008
      (a brief induction into `knowledge/PRD.md` was reverted to avoid
      PRD/constitution redundancy).
- [x] **Adopt RKA ADR-0013 early** (2026-07-24, maintainer decision): validator
      rules 8/9a/9b ported and each proven to fail by seeded violation; both
      spec bundles migrated to `knowledge/specs/`; recorded in ADR-0009.
      Validator green on 19 governed documents.
- [x] **Add the bundle index** (2026-07-25): `knowledge/index.md` now enumerates
      every governed document (20 as of ADR-0010), activating validator rule 7 (bundle-index
      integrity), which was latent while no index existed.
      Both halves proven by seeded violation (an unlisted governed document, and
      an entry that does not resolve).
      The index is OKF bundle structure, not governed knowledge: no RKA
      frontmatter, no `status`.
      Adding or removing a governed document now requires updating it.
- [x] **Promote ADR-0008** to `active` (2026-07-25): the PRD-handling decision
      has seasoned since 2026-07-22 and is in force.
- [x] **Promote ADR-0009** to `active` (2026-07-26, maintainer decision): the
      early-adoption decision has been in force since 2026-07-24, with rules 8, 9a
      and 9b gating every commit since.
      Canonical promotion of the `active` ADRs remains a later gate, now
      conditioned solely on at least one more consuming change (the "season
      through Phase 4" half was retired 2026-07-28; see `progress.md`).
- [x] **Reconcile the ported validator** against the released one (2026-08-02):
      ADR-0009's standing obligation is discharged. `rka-template` was re-cut
      upstream on 2026-07-31 as a standalone Copier template, and its first
      release v0.1.0 is the first to ship rules 8 and 9. Three divergences
      found, each a fail-open the early port lacked (rule 9c absent; nested
      bundle documents escaping 9a; a trailing-slash argument disabling 9a/9b),
      each reproduced against this repo's script before being fixed.
      Recorded in `knowledge/progress.md`; the pin in `knowledge/context.md`
      moves v0.4.0 -> v0.1.0, because the old tag no longer exists upstream.
- [ ] **Adopt upstream's validator test suite**: v0.1.0 ships
      `tests/validate-frontmatter.bats` and this repo has none.
- [ ] **Decide whether this repo becomes a Copier consumer** of the re-cut
      `rka-template` (see `knowledge/progress.md`); left open for the maintainer.
- [x] **Close the orphaned spin-up commitment** (2026-07-25, spec 002 T015): recorded
      as ADR-0010. The metric stands but is deliberately uninstrumented; PRD Section 7,
      PLAN Phase 4 item 3, and the constitution's definition of done no longer claim a
      carrier that does not exist.
- [x] **Phase 4 - archived unexecuted** (2026-07-26, maintainer decision): the
      spin-up workstream went on 2026-07-25 and the rest followed once it was
      confirmed that neither non-idempotent re-runs nor teardown residue had bitten
      in real use. Constitution invariants 3 and 4 remain stated but unverified,
      recorded as a known limitation in `knowledge/progress.md`.
      **v1 is complete; no execution work is outstanding.**
