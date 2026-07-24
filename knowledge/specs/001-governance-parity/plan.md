---
id: plan-001-governance-parity
title: Implementation plan - governance parity
status: archived
version: 0.2.0
date: 2026-07-24
type: plan
---

> **Archived 2026-07-24** with the bundle; see `spec.md` for the Extraction record.

# Implementation Plan: Governance parity

**Spec**: `docs/specs/001-governance-parity/spec.md` | **Branch**: `001-governance-parity`

## Technical context

- **Parity source of truth**:
  `/home/user/repository-knowledge-architecture/scripts/validate-frontmatter.sh` - 7 rules,
  mikefarah-`yq` (`--front-matter=extract`) + `jq`, reports all errors before exiting non-zero,
  takes the governed root as `$1` defaulting to `knowledge`. Both `yq` and `jq` are already
  pinned in this repo's `.config/mise/config.toml` `[tools]`, so a near-verbatim port works;
  no repo-specific assumptions were found in the reference script (it keys everything off the
  `KNOWLEDGE_DIR` argument and directory shape, not off the reference repo's own doc ids).
- **The broken wiring**: `.config/mise/tasks/lint.toml` `["lint:frontmatter"]` guards with
  `[ -d "knowledge" ] && [ -f "scripts/validate-frontmatter.sh" ]` and prints a skip warning
  with exit 0 otherwise. That guard is the root cause of the silent no-op: the script vanished
  (or was never committed) and nothing failed. The fix restores the script AND makes the guard
  fail when `knowledge/` exists without the script - only the no-knowledge-dir case may skip.
- **Governed-doc census** (validator input, all under `knowledge/`):
  - `constitution.md` - five fields, missing `type` (-> `constitution`). Also holds the two
    open questions for the human (its "Open questions for the human" section, lines 155-168).
  - `context.md`, `activeContext.md`, `progress.md` - five fields, missing `type`
    (-> `context`, matching the reference repo's vocabulary for all three working-state docs).
  - `adr/ADR-0001.md`, `adr/ADR-0002.md` - `status: canonical`, `adr_status: accepted`,
    missing `type` (-> `adr`); prose `## Status` at lines 18/18.
  - `adr/ADR-0003.md`..`ADR-0006.md` - `status: draft`, `adr_status: accepted`, missing
    `type`; prose `## Status` at lines 19/19/20/15. Ids match filename stems (`ADR-NNNN`, no
    slugs), so rule 4 passes as-is.
  - No `knowledge/index.md`, so rule 7 (bundle-index integrity) is latent; port it anyway.
- **Prose `## Status` sections carry substance**: ADR-0001's holds Phase 0 confirmation
  evidence; ADR-0003's records the partial reopening by ADR-0006; ADR-0006's scopes what it
  supersedes in ADR-0003. Deleting these sections without extracting that content into
  `## Context` / `## Consequences` would lose durable knowledge - extraction first is
  mandatory, mirroring the RKA extraction-before-archival rule.
- **Canonical docs are edited by this migration**: ADR-0001/0002 are `canonical`; adding
  `type` and removing the prose `## Status` is a mechanical schema migration, not a content
  change, but the promotion-evidence trail (see below) should note it and the human should see
  the diff. Do not bump their `version` beyond a patch.
- **Promotion-gate exemplar**: `docs/reviews/promotion-evidence-ADR-0001-0002-2026-07-13.md` -
  sections: proposer and reviewer; review scope; per-ADR claim-vs-artefact tables; "what might
  still be wrong (honest account)"; proposed decision for the human to record; outcome
  (appended by the human's decision, absent until then). ADR-0003..0006 claims are checkable
  against: `.config/mise/config.toml` (ADR-0003 mise toolchain), `clusters/workload/README.md`
  and `clusters/workload/flux-system/gotk-sync.yaml` (ADR-0004 deploy key / scratch branch),
  `clusters/workload/infrastructure/cert-manager/{controllers,configs}/` (ADR-0005 layered
  pattern), `.devcontainer/` (ADR-0006).
- **Scope ADR source material**: `knowledge/activeContext.md` "Decisions in flight" (scope
  identity, ecosystem review R6; repo name) and `knowledge/constitution.md` "Non-goals"
  (multi-user identity out of scope; CAPI deferred; single-user local ephemeral IDP framing).
  Rename blast radius: `url: ssh://git@github.com/x45dev/kind-talos-gitops.git` in
  `clusters/workload/flux-system/gotk-sync.yaml`; a rename breaks Flux source reconciliation
  on running clusters until the URL is updated and re-applied.
- **Upstream tracking**: RKA ADR-0012 (release-train propagation; consumers pin to releases,
  never upstream HEAD). Local consumption points: the digest-pinned devbase image in
  `.devcontainer/Dockerfile` and RKA/template convention updates. `knowledge/context.md` is the
  durable home ("System patterns" side); `activeContext.md` to-do 4 gets ticked when written.
- **Constitution check**: this plan is pure governance/documentation work plus one shell
  script; no cluster lifecycle is touched, so the engineering gates (provision/reconcile) are
  out of scope and `mise run lint` is the only verification surface. That is exactly why AC1
  (seeded violation) exists: green lint must be shown to be falsifiable again.

## Phases

### Phase 1 - Restore the gate (validator + wiring + proof)

1. Port the 7-rule reference validator to `scripts/validate-frontmatter.sh` (executable,
   shellcheck/shfmt clean - `mise run lint` runs both on all `*.sh`).
2. Harden `["lint:frontmatter"]` in `.config/mise/tasks/lint.toml`: run the script when
   `knowledge/` exists; fail with a clear ERROR if `knowledge/` exists but the script is
   missing; skip only when there is no `knowledge/` directory at all.
3. Prove the gate bites: seed a violation (remove `type` from one doc after Phase 2, or use an
   illegal `status` value now), observe `mise run lint` fail with the validator's ERROR string,
   revert, observe pass. Record the transcript in the PR description.

Note: immediately after step 1-2 and before Phase 2, `mise run lint` WILL fail (all nine docs
lack `type`). Land Phases 1 and 2 in the same change so the branch stays green, or accept the
mid-branch red as the proof for step 3.

### Phase 2 - Migrate the knowledge base

1. Backfill `type` on `knowledge/{constitution,context,activeContext,progress}.md`
   (`constitution`, `context`, `context`, `context`) and on `knowledge/adr/ADR-0001..0006.md`
   (`adr`).
2. For each ADR, extract the substantive content of its prose `## Status` section into the
   surviving sections (reopening notes -> `## Context` or `## Consequences`; verification
   evidence -> `## Consequences` or the promotion-evidence artifact), then delete the section.
3. Run `scripts/validate-frontmatter.sh` directly and via `mise run lint`; all governed docs
   pass.

### Phase 3 - Author ADR-0007 (scope identity)

1. Write `knowledge/adr/ADR-0007.md` in the new shape (six fields, `type: adr`,
   `adr_status: proposed`, `status: draft`, no prose `## Status`): decision - this repo's
   identity is the single-tenant, single-cluster local GitOps rehearsal tool its constitution
   already describes; the multi-customer ephemeral IDP becomes a separate future project with
   its own PRD, consuming this repo's verified patterns (Talos provisioning, Flux loop,
   layered Kustomizations, turnkey payload).
2. Inside the ADR, record the rename option: the name's `kind` component is stale (ADR-0001
   removed kind), options are rename-now / rename-with-next-URL-touching-change / never;
   recommend deferring until a natural URL-touching change, citing the
   `clusters/workload/flux-system/gotk-sync.yaml` GitRepository URL as the blast radius.
3. Validator run includes the new file (10 docs checked).

### Phase 4 - Prepare the promotion decision (human decides)

1. Write `docs/reviews/promotion-evidence-ADR-0003-0006-2026-07-19.md` following the
   ADR-0001/0002 exemplar: roles, scope, one claim-vs-artefact table per ADR against the
   committed tree, honest-account section, proposed decision. Propose `draft -> active` for
   ADR-0003..0006 (canonical readiness may be noted per-ADR but is a separate later gate).
2. In the same artifact, list the constitution's two open questions (PRD induction; unified
   definition-of-done synthesis) as the blockers on constitution/context/PRD progression, with
   the PRD's outside-knowledge `status: draft` tension stated plainly.
3. Stop. The human reads the evidence, records decisions, and (if affirmative) sets statuses;
   the agent may act as scribe afterwards but never sets the statuses on its own initiative.

### Phase 5 - Upstream tracking note + working-state closure

1. Add the release-pinned upstream tracking statement to `knowledge/context.md` (System
   patterns): devbase digest bumps and RKA/template convention updates are pulled deliberately
   at tagged releases per RKA ADR-0012; ad hoc HEAD-tracking is out.
2. Update `knowledge/activeContext.md` (tick to-dos 1 and 4; move to-do 2 to
   "awaiting human decision" with a pointer to the evidence artifact; record ADR-0007 under
   decisions) and `knowledge/progress.md` (drop the validator no-op known issue; note the
   restored gate and the migration under "What works"; name Phase 4 hardening as the successor
   spec `docs/specs/002-*`).

## Risks and mitigations

- **Knowledge loss on prose-Status deletion**: the sections hold verification and reopening
  content. Mitigation: extraction-first rule in Phase 2 step 2; reviewer diffs each ADR for
  dropped sentences, not just schema shape.
- **Mid-branch red lint between validator restore and doc migration**: Phases 1-2 land
  together in one change; the seeded-violation proof is captured deliberately, not left as an
  accidental broken state.
- **Editing canonical documents**: ADR-0001/0002 are `canonical`; the migration is mechanical
  but touches them. Mitigation: patch-level version bump only, called out in the PR and in the
  evidence artifact so the human sees it explicitly.
- **Silent-skip pattern recurrence**: other lint sub-tasks (`lint:shellcheck`, `lint:shfmt`)
  also skip-when-empty; that is correct for them (no files is a legitimate state) but the
  frontmatter guard conflated "no governed dir" with "gate missing". Mitigation: the hardened
  guard distinguishes the two; the distinction is commented in `lint.toml`.
- **Validator divergence from the upcoming template release**: `rka-template` spec
  `001-first-train` will ship the same rules via tag. Mitigation: open-question note in
  spec.md; on template adoption, diff the two scripts and record the outcome in
  `knowledge/progress.md`.
- **Rename pressure from ADR-0007**: recording the rename option may invite doing it now.
  Mitigation: the ADR's recommendation is explicit deferral; the Flux URL blast radius is
  documented inside the decision itself.

## Definition of done

All six acceptance criteria in `spec.md` verified, with the seeded-violation lint transcript,
the validator pass output (10 files checked), and links to ADR-0007 and the evidence artifact
recorded in the PR description. The human promotion decision itself is explicitly NOT part of
done: done is the decision being fully prepared and awaiting the human.
