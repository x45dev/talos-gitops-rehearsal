---
id: activeContext
title: Active Context
status: active
version: 0.1.2
date: 2026-07-22
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
Next execution phase is Phase 4 (lifecycle, idempotency, metrics hardening);
no work has started on it.

## Decisions in flight

- **Scope identity (ecosystem review R6).** This repo is, by its own
  constitution, a single-user single-cluster local GitOps rehearsal tool;
  multi-user identity is an explicit non-goal.
  The multi-customer ephemeral IDP ambition should become a separate future
  project (own PRD) that consumes this repo's verified patterns, rather than
  living implicitly in this repo's framing.
  Proposed, not yet decided.
- **Repo name.** `kind` was removed entirely by ADR-0001; the name
  `kind-talos-gitops` is a stale artifact.
  A rename is cheap but touches the Flux `GitRepository` URL
  (`clusters/workload/flux-system/gotk-sync.yaml`), so it should ride with a
  deliberate change, not happen casually.

## Upstream tracking (2026-07-22 survey)

Surveyed the three upstreams: `rka-template` at its latest tag v0.4.0, the RKA
reference repo and `agent-standards` at `main`.
The most recent released conventions are already applied here: the six-field
frontmatter schema, `adr_status`, the rule-current validator (rules 1-7), and
`hide = true` on the aggregate lint tasks.
`agent-standards` adds nothing to pull: its ADR-0005 declines to enforce a spec
lifecycle outside RKA-adopted repos, and its agent entry points are user-level
config, not repo-distributed.

One newer convention is pending, not applied: RKA ADR-0013 governs spec bundles
under `knowledge/specs/` with validator rules 8 and 9 (a bundle whose tasks are
all complete must be `archived` and carry an extraction record).
Those rules live only in the RKA reference repo's `main`; they have not shipped
in `rka-template` v0.4.0, so per ADR-0012 (consume at tagged releases, never
HEAD) they are deliberately not adopted yet.
The trigger to revisit is the first `rka-template` release that carries rules 8
and 9; at that point the finished `docs/specs/001-governance-parity/` bundle
migrates into `knowledge/specs/` and is retired (see `progress.md`).

## Next steps (to-do)

- [x] **Restore `scripts/validate-frontmatter.sh`** - done: the validator is
      present and rule-current with `rka-template` v0.4.0 (rules 1-7), and the
      `lint:frontmatter` gate hard-fails when it is missing rather than
      no-opping.
      Confirmed green (11 files) by the 2026-07-22 survey.
- [x] **Adopt release-pinned upstream tracking** (ecosystem review R1):
      recorded in `knowledge/context.md` (System patterns) and in the survey
      note above.
      Pins verified 2026-07-22: `rka-template` v0.4.0; RKA reference and
      `agent-standards` consumed only through tagged releases per ADR-0012,
      never at upstream HEAD.
- [ ] **Promote or progress the `draft` governance backlog**: ADR-0003 to
      ADR-0006 are `accepted` but still `status: draft`; the constitution,
      context, and PRD are `draft` with two open constitution questions.
- [ ] **Phase 4** (lifecycle, idempotency, metrics hardening) per
      `docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md`.
