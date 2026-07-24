---
id: spec-001-governance-parity
title: Governance parity - restore the frontmatter gate, migrate the knowledge base, settle scope
status: archived
version: 0.2.0
date: 2026-07-24
type: spec
---

> **Archived 2026-07-24.** All 18 tasks shipped (see `tasks.md` execution evidence) and
> the pending human decisions were recorded on 2026-07-22, so this bundle is retired
> rather than left `draft` (a completed spec's status must be advanced, per the
> spec-driven-work guidance). See the Extraction record at the end of this file.
> This is an ungoverned retirement under `docs/specs/`; migration into a governed
> `knowledge/specs/` bundle waits for RKA ADR-0013 shipping in a tagged `rka-template`
> release (ADR-0012).

# Feature Specification: Governance parity

**Branch**: `001-governance-parity` | **Created**: 2026-07-19 | **Status**: draft
**Input**: `knowledge/activeContext.md` to-dos 1, 2 and 4 plus both "Decisions in flight";
`knowledge/progress.md` "What's left" / "Known issues"; 2026-07-19 ecosystem review findings R1/R6.

## Why (problem statement)

The repo's governance gate is a silent no-op: `.config/mise/tasks/lint.toml` (`lint:frontmatter`)
calls `scripts/validate-frontmatter.sh`, which does not exist, and the task's guard prints a
skip warning and exits 0 instead of failing. Every `mise run lint` since has passed vacuously.
Meanwhile the knowledge base has drifted from the current RKA schema: no governed document under
`knowledge/` carries the required `type` field (six-field schema per RKA RFC-003 section 3 /
ADR-0011), and all six ADRs still carry a prose `## Status` section retired by RKA ADR-0007 in
favour of `adr_status`. The governance backlog has also stalled: ADR-0003..0006 are
`adr_status: accepted` yet `status: draft`, and the constitution, context, and PRD sit in `draft`
with two open constitution questions unanswered. Finally, two decisions are in flight but
unrecorded as decisions: the repo's identity (single-tenant local GitOps rehearsal, with the
multi-customer ephemeral IDP as a separate future project) and the stale `kind-talos-gitops`
name. Until this feature lands, the repo cannot prove its own documents obey the standard it
claims to practise, and its scope remains implicit.

## User stories

- **US1 - Repo maintainer**: As the maintainer, `mise run lint` actually validates frontmatter
  again, so a schema violation in `knowledge/` fails the gate instead of skipping silently, and
  I can trust green lint to mean governed docs are compliant.
- **US2 - Agent collaborator**: As an agentic assistant working in this repo, every governed
  document carries the current six-field schema (including `type`) and ADRs carry machine-readable
  `adr_status` with no prose `## Status` duplication, so retrieval and governance rules apply
  mechanically rather than by convention.
- **US3 - Human reviewer**: As the non-author reviewer, I receive a promotion-evidence artifact
  for the ADR-0003..0006 batch in the same shape as the ADR-0001/0002 exercise, so I can
  adjudicate the promotion decision on evidence; the agent prepares, I decide.
- **US4 - Future IDP project owner**: As the owner of the eventual multi-customer ephemeral IDP,
  an accepted-or-proposed scope ADR names this repo as a single-tenant rehearsal tool and my
  project as its separate consumer, so I inherit verified patterns instead of an ambiguous scope.

## Functional requirements

- **FR1**: `scripts/validate-frontmatter.sh` exists and enforces the 7 reference rules ported
  from `repository-knowledge-architecture/scripts/validate-frontmatter.sh`: six required
  non-empty fields (`id`, `title`, `status`, `version`, `date`, `type`); legal `status`; unique
  `id`; type-keyed id/filename convention (ADR-NNNN ids, optional kebab slug in filenames);
  `adr_status` present and legal on every doc under `knowledge/adr/`; exactly one constitution;
  bundle-index integrity when `knowledge/index.md` exists (it does not today, so rule 7 is
  latent but ported for parity).
- **FR2**: The `lint:frontmatter` task in `.config/mise/tasks/lint.toml` runs the restored
  script and its guard is hardened: when `knowledge/` exists but the script is missing, the task
  fails instead of printing a skip warning and exiting 0. The silent no-op class of failure is
  closed, not just this instance of it.
- **FR3**: All nine governed documents pass the restored validator:
  `knowledge/{constitution,context,activeContext,progress}.md` and
  `knowledge/adr/ADR-0001..0006.md` gain `type` (vocabulary matched to the reference repo:
  `constitution`, `context`, `adr`); the six ADRs' prose `## Status` sections are removed with
  their substantive content (verification notes, reopening cross-references) extracted into the
  surviving sections first, per the extraction-before-deletion rule.
- **FR4**: `knowledge/adr/ADR-0007.md` exists, declaring the single-tenant local-rehearsal
  scope as this repo's identity and naming the multi-customer ephemeral IDP as a separate future
  project (own PRD) that consumes this repo's verified patterns. The ADR records the repo-rename
  question as an option inside it: `kind` is a removed component (ADR-0001), the rename's blast
  radius is the Flux `GitRepository` URL in `clusters/workload/flux-system/gotk-sync.yaml`, and
  the recommendation is to defer the rename until a natural URL-touching change. The ADR carries
  `adr_status: proposed` (or `accepted` if the human records acceptance) and the new shape:
  six fields, `type: adr`, no prose `## Status` section.
- **FR5**: A promotion-evidence artifact
  `docs/reviews/promotion-evidence-ADR-0003-0006-2026-07-19.md` exists, following
  `docs/reviews/promotion-evidence-ADR-0001-0002-2026-07-13.md`: proposer/reviewer roles, review
  scope, per-ADR claim-vs-artefact verification tables, an honest "what might still be wrong"
  section, and a proposed decision that leaves the recorded human decision as the explicit final
  step. The artifact also surfaces the constitution's two open questions (PRD induction; unified
  definition-of-done synthesis) as blockers-or-not for the constitution/context/PRD promotions,
  without answering them on the human's behalf.
- **FR6**: Release-pinned upstream tracking is documented in `knowledge/context.md` (or
  `knowledge/activeContext.md`): devbase image digest bumps and RKA/template convention updates
  are pulled deliberately at tagged releases, never ad hoc against upstream HEAD, per RKA
  ADR-0012.
- **FR7**: The working-state pair is updated on completion: `knowledge/activeContext.md` to-dos
  1, 2 and 4 ticked or progressed, `knowledge/progress.md` known-issue on the validator no-op
  removed, and Phase 4 named as the next execution focus via its own successor spec.

## Non-goals (scoped out, with reasons)

- **Phase 4 (lifecycle, idempotency, metrics hardening)**: its own future feature spec
  (`docs/specs/002-*`); this spec only names it as the successor. Batching engineering hardening
  with governance parity would couple unrelated verification surfaces.
- **Executing any promotion**: the agent prepares evidence; status changes on ADR-0003..0006,
  constitution, context, or PRD are recorded only by the human (RKA RFC-000 P4, RFC-002
  section 4).
- **Performing the repo rename**: recorded as an option inside ADR-0007 with a deferral
  recommendation; renaming now would touch the live Flux `GitRepository` URL for no functional
  gain.
- **Porting the reference BATS suite** (`tests/validate-frontmatter.bats`, 19 unit + 1 smoke):
  the tagged `rka-template` release train is the intended delivery vehicle for the tested
  validator; here the seeded-violation check (AC1) proves the gate bites. Revisit when this repo
  adopts the template's tagged release.
- **Deciding PRD induction into `knowledge/`**: the constitution explicitly leaves this to the
  human; this spec surfaces it (FR5) but does not move the file.

## Acceptance criteria

1. Seeded-violation proof: with a deliberate violation introduced in a `knowledge/` doc (for
   example `type` removed or an illegal `status`), `mise run lint` fails with the validator's
   ERROR output; with the violation reverted, it passes. This proves the no-op is fixed, not
   merely that a script exists.
2. All nine governed documents pass the ported validator: `scripts/validate-frontmatter.sh`
   exits 0 reporting 10 files checked once ADR-0007 lands (9 pre-existing + ADR-0007).
3. `knowledge/adr/ADR-0007.md` exists with `adr_status: proposed` or `accepted`, six-field
   frontmatter including `type: adr`, no prose `## Status` section, and contains both the
   scope-identity decision and the recorded rename option naming
   `clusters/workload/flux-system/gotk-sync.yaml` as the blast radius.
4. `docs/reviews/promotion-evidence-ADR-0003-0006-2026-07-19.md` exists for the ADR-0003..0006
   batch, ending in a proposed-decision section that assigns the recorded decision to the human.
5. A grep of `knowledge/adr/` shows zero prose `## Status` sections; a grep of `knowledge/`
   shows `type:` in every governed doc.
6. `knowledge/context.md` or `knowledge/activeContext.md` contains the release-pinned upstream
   tracking statement citing RKA ADR-0012.

## Open questions

- **PRD frontmatter tension**: `docs/planning/PRD.md` carries `status: draft` while living
  outside `knowledge/`; RKA's rule is that documents outside the governed root carry no
  `status`. Whether to induct the PRD into `knowledge/` (dropping or keeping governance) is the
  constitution's own first open question and stays with the human; the evidence artifact must
  present it, not resolve it.
- **Validator source lineage**: this spec ports directly from the RKA reference repo per
  activeContext to-do 1's first option. If the tagged `rka-template` release (its spec
  `001-first-train`) ships first, the implementer should confirm the ported script matches the
  released one and note any divergence in `knowledge/progress.md`.
- **ADR-0007 initial `adr_status`**: authored as `proposed` by default; the human may record
  `accepted` in the same review that adjudicates the promotion-evidence artifact. Either
  satisfies AC3.

## Extraction record (2026-07-24)

Durable knowledge from this bundle already lives in the governed knowledge base and the
repo's standing artifacts; nothing else required extraction at archival:

- The restored validator and hardened gate: `scripts/validate-frontmatter.sh` +
  `.config/mise/tasks/lint.toml` (`lint:frontmatter`), recorded in
  `knowledge/progress.md` "What works".
- The scope-identity decision and rename option: `knowledge/adr/ADR-0007.md`
  (accepted 2026-07-22).
- The release-pinned upstream-tracking pattern (RKA ADR-0012):
  `knowledge/context.md` "System patterns".
- The promotion decisions this spec prepared: recorded in
  `docs/reviews/promotion-evidence-ADR-0003-0006-2026-07-19.md` Outcome
  (decision 2026-07-22) and in the promoted documents themselves.
- Open questions this spec surfaced (PRD induction; definition-of-done synthesis):
  both resolved 2026-07-22, recorded in `knowledge/constitution.md`
  "Open questions for the human" and `knowledge/adr/ADR-0008.md`.

Superseded by: no successor needed for the governance-parity work itself; Phase 4
execution continues in `docs/specs/002-phase-4-lifecycle-hardening/`.
