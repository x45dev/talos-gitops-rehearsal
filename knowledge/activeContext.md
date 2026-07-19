---
id: activeContext
title: Active Context
status: active
version: 0.1.1
date: 2026-07-19
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

## Next steps (to-do)

- [ ] **Restore `scripts/validate-frontmatter.sh`** - referenced by
      `.config/mise/tasks/lint.toml` but absent, so frontmatter linting
      silently no-ops today.
      Copy the current validator from the RKA reference repo (or wait for the
      tagged `rka-template` release per the release-train model and take it
      from there).
- [ ] **Promote or progress the `draft` governance backlog**: ADR-0003 to
      ADR-0006 are `accepted` but still `status: draft`; the constitution,
      context, and PRD are `draft` with two open constitution questions.
- [ ] **Phase 4** (lifecycle, idempotency, metrics hardening) per
      `docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md`.
- [ ] **Adopt release-pinned upstream tracking** (ecosystem review R1):
      devbase image digest bumps and any RKA/template convention updates are
      pulled deliberately at tagged releases, not ad hoc.
