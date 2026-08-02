# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **spike:** Replace CAPD spike with green talosctl bootstrap probe
- **phase1:** Decide host-native dev environment, remove dangling devcontainer tasks
- **phase2:** Stand up clusters/workload GitOps structure, Flux bootstrap wiring
- **phase3:** Cert-manager + local Root CA issuer as first per-component Flux layering
- **phase3:** Dex (GitHub OIDC) + Cloudflare Tunnel turnkey payload
- **changelog:** Wire git-cliff automated changelog generation
- **devcontainer:** Add cross-host devcontainer with opt-in cluster overlay (#9)
- **governance:** RKA parity migration - restore validator, migrate docs, scope ADR
- **governance:** Adopt the RKA ADR-0013 spec-lifecycle gate early

### Changed

- Initial project scaffold (mise, sops, lefthook, vale, docs, README, LICENSE)
- **plan:** Add implementation roadmap grounded in live spike probe
- **review:** Bound readyz wait and add set -e to teardown task
- **document:** Sync docs/planning/PLAN with completed Phase 0 outcome
- **document:** Remove stale devcontainer pre-push hook comment now that host-native decision is closed
- **document:** Remove dead hadolint/devcontainer references from lint task, hook, README
- **phase2:** Close out Phase 2 in the plan and PRD
- **document:** Fixed one doc gap: PRD 3.1 didn't mention the git-credentials deploy-key secret injection now part of the bootstrap flow; everything else (README, clusters/workload/README, plan, task file) was already in sync.
- Add cert-manager to root README project-structure tree
- **phase3:** Temporarily point GitRepository at scratch branch for live verification
- Revert "test(phase3): temporarily point GitRepository at scratch branch for live verification"
- **plan:** Mark Phase 3 done and live-verified
- **planning:** Fix RKA frontmatter conformance gaps
- **changelog:** Regenerate docs/CHANGELOG.md after final history reword
- **changelog:** Regenerate docs/CHANGELOG.md after lint fixes
- **knowledge:** Brownfield discovery - constitution, 5 ADRs, context doc
- **knowledge:** Promote ADR-0001/0002 draft->active; propose canonical
- **knowledge:** Promote ADR-0001/0002 active->canonical (recorded human decision)
- **devcontainer:** Add idempotent launch script (#10)
- **knowledge:** Add working-state pair from 2026-07-19 ecosystem review
- **specs:** Add governance-parity spec-kit plan
- **changelog:** Regenerate docs/CHANGELOG.md automatically at pre-commit
- **docs:** Apply markdownlint auto-fixes left unstaged by the lint hook
- **document:** Sync README and context.md docs with pre-commit changelog regeneration change
- **knowledge:** Record 2026-07-22 upstream convention survey in working state
- **governance:** Record RKA lifecycle decisions - promote ADR-0003..0007, context
- **governance:** Promote the constitution draft -> active
- **governance:** Induct the PRD into knowledge/ as a governed document
- **governance:** Revert PRD induction; keep it unmanaged per ADR-0008
- **specs:** Add the Phase 4 lifecycle-hardening feature spec (002)
- **specs:** Complete the Phase 4 bundle with plan.md and tasks.md
- **specs:** Reconcile Phase 4 bundle after gate-3 adversarial review
- **governance:** Reconcile doubt-driven review findings on the session's work
- **governance:** Add the bundle index and promote ADR-0008 to active
- Add a governance and docs gate; document the index obligation
- **specs:** Descope 002 - withdraw the spin-up measurement workstream
- **specs:** Reconcile the second gate-3 review of the descoped 002 bundle
- **governance:** Close the orphaned spin-up commitment (ADR-0010, spec 002 T015)
- **governance:** Promote ADR-0009 to active
- **governance:** Archive Phase 4 unexecuted and declare v1 complete
- **governance:** Retire the dead half of the canonical-promotion gate
- **devcontainer:** Re-pin devbase and single-source the agent-config wiring
- **env:** Move Cloudflare account/zone IDs out of the public tree
- **devcontainer:** Make the devcontainer self-contained for public consumption
- **readme:** Frame the governance conventions and verification claims for outside readers
- **document:** Fix stale devbase/context.md claims; docs, lint already clean
- Rename the project to talos-gitops-rehearsal
- Adopt the public no-committed-secrets posture
- **review:** Widen secrets-leak-guard regex; update PRD's stale deploy-key architecture text
- **document:** Sync stale git-credentials/deploy-key facts in context.md; lint already clean
- **document:** Mark ADR-0004's deploy-key decision superseded in place
- **governance:** Adopt the validator's bats suite from rka-template v0.1.0
- **governance:** Correct ADR-0010's overtaken consequence and promote it to active
- **governance:** Retire the stale devcontainer coupling limitation
- **governance:** Cite churning files by anchor instead of line number
- **governance:** Drop the PRD's drifting line ranges, keep its Section references

### Fixed

- **phase2:** Guard test-talos-spike:cilium against helm-controller adoption
- **phase2:** Close findings from doubt-driven-development review
- **review:** Fix(phase2): fail fast on empty GitHub known_hosts fetch
- **lint:** Repair broken mise lint tasks
- **devcontainer:** Run postCreateCommand from devcontainer-up.sh (#11)
- **hooks:** Fail open in sops-integrity-check when the AGE key is absent
- **hooks:** Order changelog regeneration before the parallel lint pass
- **hooks:** Serialize changelog regen and lint; accept no-mistakes commit type
- **governance:** Close three validator fail-opens found reconciling against rka-template v0.1.0

<!-- generated by git-cliff -->
