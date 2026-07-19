---
id: tasks-001-governance-parity
title: Task list - governance parity
status: draft
version: 0.1.0
date: 2026-07-19
type: tasks
---

# Tasks: Governance parity

**Plan**: `docs/specs/001-governance-parity/plan.md`. `[P]` = parallelizable with the previous
task. Paths are repo-relative in `kind-talos-gitops` unless prefixed.

## Phase 1 - Restore the gate (one change together with Phase 2)

- [ ] **T001** Read the reference validator
      (`/home/user/repository-knowledge-architecture/scripts/validate-frontmatter.sh`); list
      each of the 7 rules and its ERROR string; confirm `yq`/`jq` availability against
      `.config/mise/config.toml` `[tools]`.
- [ ] **T002** Port the validator to `scripts/validate-frontmatter.sh` (executable bit set;
      keep the `KNOWLEDGE_DIR="${1:-knowledge}"` root argument; keep rule 7 even though no
      `knowledge/index.md` exists yet). Run `shellcheck` and `shfmt -i 2 -ci -sr` on it (both
      run inside `mise run lint`).
- [ ] **T003** Harden `["lint:frontmatter"]` in `.config/mise/tasks/lint.toml`: run the script
      when `knowledge/` exists; hard-fail (exit 1 with an ERROR message) when `knowledge/`
      exists but `scripts/validate-frontmatter.sh` is missing; skip with a notice only when
      there is no `knowledge/` directory. Comment the distinction.

## Phase 2 - Migrate the knowledge base (same change as Phase 1)

- [ ] **T004** Backfill `type` in
      `knowledge/constitution.md` (`constitution`) and
      `knowledge/{context,activeContext,progress}.md` (`context`), matching the reference
      repo's vocabulary.
- [ ] **T005** [P] Backfill `type: adr` in `knowledge/adr/ADR-0001.md` .. `ADR-0006.md`.
      Patch-level `version` bump only on the two `canonical` docs (ADR-0001, ADR-0002).
- [ ] **T006** For each of `knowledge/adr/ADR-0001..0006.md`: extract the substantive content
      of the prose `## Status` section (ADR-0001 Phase 0 confirmation evidence; ADR-0003
      reopened-by-ADR-0006 note; ADR-0006 supersedes-scope note; verify the rest) into
      `## Context` / `## Consequences`, then delete the `## Status` section. Diff-review each
      file for dropped sentences.
- [ ] **T007** Run `scripts/validate-frontmatter.sh` directly: exit 0, 9 files checked. Then
      `mise run lint`: green end to end.
- [ ] **T008** Seeded-violation proof (spec AC1): temporarily remove `type` from one governed
      doc, confirm `mise run lint` fails with the validator's ERROR output, revert, confirm
      green. Capture both transcripts for the PR description.

## Phase 3 - ADR-0007 (scope identity)

- [ ] **T009** Author `knowledge/adr/ADR-0007.md`: six-field frontmatter (`id: ADR-0007`,
      `status: draft`, `adr_status: proposed`, `type: adr`), no prose `## Status`. Decision:
      single-tenant single-cluster local GitOps rehearsal is this repo's identity; the
      multi-customer ephemeral IDP is a separate future project (own PRD) consuming this
      repo's verified patterns. Sources: `knowledge/activeContext.md` "Decisions in flight",
      `knowledge/constitution.md` "Non-goals".
- [ ] **T010** Inside ADR-0007, record the repo-rename option (`kind` removed by ADR-0001):
      options rename-now / rename-with-next-URL-touching-change / never; name the Flux
      `GitRepository` URL in `clusters/workload/flux-system/gotk-sync.yaml`
      (`ssh://git@github.com/x45dev/kind-talos-gitops.git`) as the blast radius; recommend
      deferral until a natural URL-touching change.
- [ ] **T011** Re-run `scripts/validate-frontmatter.sh`: exit 0, 10 files checked.

## Phase 4 - Promotion evidence (prepare only; human decides)

- [ ] **T012** Write `docs/reviews/promotion-evidence-ADR-0003-0006-2026-07-19.md` following
      `docs/reviews/promotion-evidence-ADR-0001-0002-2026-07-13.md`: roles, review scope, one
      claim-vs-artefact table per ADR checked against `.config/mise/config.toml` (ADR-0003),
      `clusters/workload/README.md` + `clusters/workload/flux-system/gotk-sync.yaml`
      (ADR-0004), `clusters/workload/infrastructure/cert-manager/{controllers,configs}/`
      (ADR-0005), `.devcontainer/` (ADR-0006); honest "what might still be wrong" section;
      proposed decision `draft -> active` left for the human to record.
- [ ] **T013** [P] In the same artifact, present the constitution's two open questions (PRD
      induction into `knowledge/`; unified definition-of-done synthesis) as the gate on
      constitution/context/PRD progression, including the `docs/planning/PRD.md`
      outside-knowledge `status: draft` tension. Present, do not answer.
- [ ] **T014** Hand off: no `status` field changes on ADR-0003..0006, constitution, context,
      or PRD in this feature. The human's recorded decision (and any scribe work after it) is
      a separate follow-up change.

## Phase 5 - Upstream tracking + working-state closure

- [ ] **T015** Add the release-pinned upstream tracking statement to `knowledge/context.md`
      (System patterns section): devbase image digest bumps (`.devcontainer/Dockerfile`) and
      RKA/template convention updates are pulled deliberately at tagged releases per RKA
      ADR-0012, never ad hoc against upstream HEAD.
- [ ] **T016** Update `knowledge/activeContext.md`: tick to-dos 1 (validator) and 4 (upstream
      tracking); move to-do 2 to awaiting-human-decision with a pointer to the T012 artifact;
      record ADR-0007 as the scope-identity decision; leave the rename as recorded-deferred.
- [ ] **T017** [P] Update `knowledge/progress.md`: remove the validator no-op known issue; add
      the restored gate, schema migration, and ADR-0007 under "What works"; name Phase 4
      hardening as the successor spec (`docs/specs/002-*`, not scoped here).

## Exit

- [ ] **T018** Verify all six acceptance criteria in `spec.md`; attach the T008 transcripts
      and the T007/T011 validator outputs as evidence in the PR description.
