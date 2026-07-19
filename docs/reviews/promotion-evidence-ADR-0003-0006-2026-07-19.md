# Promotion evidence: ADR-0003..ADR-0006 (draft -> active)

Uninducted working material - the in-repo formal-review record RFC-002 section 4
requires before a status change on governed documents. Second exercise of the RKA
promotion gate in this repository (first: ADR-0001/0002, 2026-07-13, see
`promotion-evidence-ADR-0001-0002-2026-07-13.md`). Prepared as part of the
governance-parity feature (`docs/specs/001-governance-parity/`).

## Proposer and reviewer

- **Proposer (author side):** AI agent (Claude). Furnishes the evidence below; may
  advocate; **does not execute the promotion** (RFC-000 P4, RFC-002 section 4).
- **Non-author reviewer (the gate):** the human. ADR-0003..0005 were authored by a
  prior discovery agent and ADR-0006 by a dev-session agent; their promotion is
  proposed by an agent, so the human is the qualifying non-author reviewer who
  adjudicates this evidence and records the decision.

## Review scope

- **Documents:** `knowledge/adr/ADR-0003.md` .. `knowledge/adr/ADR-0006.md`, all
  currently `status: draft`, `adr_status: accepted`. Proposed move: `draft -> active`
  (canonical readiness is a separate later gate, noted per-ADR where relevant).
- **What was examined:** every mechanically-checkable claim in each ADR against the
  actual committed repository state, plus internal consistency. Runtime behaviour was
  **not** re-executed (no Talos/Docker environment in this review context); see "What
  might still be wrong".
- **Also in scope, for disclosure:** the same change that adds this file performed a
  mechanical schema migration on ALL governed documents (added the required `type`
  field, removed prose `## Status` sections with extraction-first). That migration
  touched the two `canonical` documents ADR-0001/0002 (patch bump `1.0.0 -> 1.0.1`,
  `type: adr` added, prose `## Status` content extracted into the intro/Consequences).
  No decision content was altered, but per RFC-002 the human should eyeball those two
  diffs explicitly.

## Verification evidence

### ADR-0003 (host-native mise toolchain instead of a devcontainer for v1)

| ADR claim | Checkable artefact | Result |
| --- | --- | --- |
| Toolchain is fully `mise`-managed, versions pinned in `[tools]` | `.config/mise/config.toml` `[tools]` | **Confirmed** - age, bats, flux2 `2.9.0` (pin annotated), git-cliff, hadolint, helm, jq, kubectl, lefthook, lychee, sops, talosctl, vale, yq |
| Dangling `setup:project` and `test:devcontainer` tasks removed | `.config/mise/tasks/` | **Confirmed absent** - no task definition anywhere under the tasks dir |
| AGE key bootstrap covered by `sops:project:generate-keypair` instead | `.config/mise/tasks/secrets.toml:27` | **Confirmed** - task exists |
| "No `.devcontainer/` exists for v1" (consequence) | `.devcontainer/` | **Superseded, coherently**: `.devcontainer/` now exists, added by ADR-0006 via the exact revisit trigger this ADR named; the reopening is recorded in this ADR's Consequences. The laptop-host-native decision itself is unchanged |

The acceptance provenance is an inference from the plan (stated twice independently:
Phase 1 status and "Decisions" item 2), now recorded in the ADR's Context section.

### ADR-0004 (persistent SSH deploy key; scratch-branch local iteration)

| ADR claim | Checkable artefact | Result |
| --- | --- | --- |
| Flux `GitRepository` authenticates via a deploy-key secret over SSH | `clusters/workload/flux-system/gotk-sync.yaml` | **Confirmed** - `secretRef: git-credentials`, `url: ssh://git@github.com/x45dev/kind-talos-gitops.git` |
| Private key half stored encrypted in the project SOPS secrets file | `.config/mise/.env.sops.yaml:15` | **Confirmed** - `FLUX_GIT_DEPLOY_KEY: ENC[AES256_GCM,...]` |
| Scratch-branch repoint mechanism, tracking `main` by default | `gotk-sync.yaml` (`ref.branch: main`, repoint instructions in header comment); `clusters/workload/README.md` "Local iteration" | **Confirmed** - `kubectl patch gitrepository/flux-system` commands documented both places, plus delete-the-remote-branch guidance |
| Stale-scratch-branch detection is an accepted gap | `clusters/workload/README.md` lines 86-89 | **Confirmed** - stated verbatim as an accepted single-developer gap |
| `flux-system` egress-unrestricted NetworkPolicies accepted for v1 | `clusters/workload/README.md` "Known limitations" | **Confirmed** - recorded with the same framing the ADR cites |

Note: the per-cycle-key rejection rationale is honestly marked "inference, low
confidence" in the ADR itself - the source plan states the preference without a
reason. That honesty is a point in favour of `active`, not against.

### ADR-0005 (layered controllers/configs Kustomization pattern)

| ADR claim | Checkable artefact | Result |
| --- | --- | --- |
| cert-manager split into two Flux Kustomization CRs with `dependsOn` | `clusters/workload/infrastructure/cert-manager.yaml` | **Confirmed** - `cert-manager-configs` carries `dependsOn: cert-manager-controllers` |
| `controllers/` = namespace + HelmRepository + HelmRelease; `configs/` = issuer chain | `clusters/workload/infrastructure/cert-manager/{controllers,configs}/` | **Confirmed** - controllers: `namespace.yaml`, `helmrepository.yaml`, `helmrelease.yaml`; configs: `selfsigned-clusterissuer.yaml`, `root-ca-certificate.yaml`, `ca-clusterissuer.yaml` |
| Root aggregation lists `cert-manager.yaml` only, never the subdirs (no double reconcile) | `clusters/workload/infrastructure/kustomization.yaml` | **Confirmed** - subdirs deliberately absent, with an explanatory comment matching the ADR |
| Ordering gate rests on helm-controller default wait, not `wait: true` alone | `cert-manager.yaml` controllers CR comment block | **Confirmed** - the corrected attribution (and the do-not-set-`disableWait` warning) is recorded at the point of use |
| Cilium stays flat; Dex and Cloudflare Tunnel did not need the split | `infrastructure/kustomization.yaml`, `dex.yaml`, `cloudflare-tunnel.yaml` | **Confirmed** - Cilium reconciled via the root path; Dex and the tunnel are each a single Kustomization CR (they use cross-component `dependsOn` ordering, but no controllers/configs split), consistent with the ADR's meaning of "flat" |

### ADR-0006 (add a devcontainer, reopening ADR-0003)

| ADR claim | Checkable artefact | Result |
| --- | --- | --- |
| `.devcontainer/` exists with the four named files | `.devcontainer/` | **Confirmed** - `Dockerfile`, `compose.yaml`, `compose.cluster.yaml`, `devcontainer.json` |
| Thin Dockerfile `FROM`s the digest-pinned devbase and adds a Docker CLI | `.devcontainer/Dockerfile` | **Confirmed** - `FROM ghcr.io/x45dev/devbase@sha256:aeba05f9...`, `docker-ce-cli` install, digest-pin rationale in header |
| Default compose is sandboxed: no Docker socket, no host networking | `.devcontainer/compose.yaml` | **Confirmed** - no `docker.sock` mount and no `network_mode` anywhere in the default file; the header comments state the security intent |
| Cluster capability is an explicit opt-in overlay | `.devcontainer/compose.cluster.yaml` | **Confirmed** - `user: root` (for socket-gid alignment only), `network_mode: host`, `/var/run/docker.sock` mount, `stat -c %g` gid-alignment logic all present, only in the overlay |

The 2026-07-18 VPS validation claims (in-container SOPS decryption, toolchain
provisioning, socket reach under the overlay) rest on the ADR's own recorded
validation run, not re-executed here.

## What might still be wrong (honest account)

1. **No live re-execution.** As with the ADR-0001/0002 review, this verifies the
   committed artefacts, not runtime behaviour. ADR-0006's VPS validation and
   ADR-0004's scratch-branch Phase 3 verification are trusted from their own recorded
   runs.
2. **Acceptance provenance for ADR-0003..0005 is inferential.** All three infer
   `accepted` from the planning document's closure markers rather than an explicit
   native acceptance record. Each inference is marked with its confidence in the ADR
   itself; the human accepting this promotion implicitly ratifies those inferences.
3. **ADR-0005's "flat" phrasing.** Dex and the Cloudflare Tunnel are single
   Kustomization CRs but do participate in `dependsOn` chains (dex depends on
   cert-manager-configs; the tunnel on dex). "Flat" is accurate for the
   controllers/configs split the ADR is about, but a literal reading could mislead.
   Non-blocking; worth a clarifying sentence on next edit.
4. **This proposer also performed the schema migration under review disclosure
   above.** The migration diffs (especially the two canonical ADRs) should be
   reviewed by the human as part of this same sitting.

## Gate on the constitution / context / PRD progression (presented, not answered)

The constitution, `knowledge/context.md`, and `docs/planning/PRD.md` remain `draft`.
Two open questions, both recorded in `knowledge/constitution.md` "Open questions for
the human", gate their progression, and both are the human's to answer:

1. **PRD induction.** Should `docs/planning/PRD.md` be inducted as a
   `knowledge/specs/` feature specification? Tension to weigh: the PRD currently
   carries `status: draft` while living OUTSIDE the governed `knowledge/` root, and
   RKA's rule (RFC-001 section 2 / reference ADR-0009) is that ungoverned documents
   carry no `status`. Either induct it (it gains governance) or strip the `status`
   field (it stays working material) - the current halfway state is the one option
   that cannot stand long-term.
2. **Unified definition-of-done synthesis.** The constitution's definition of done is
   a synthesis of two agreeing-but-separate PRD sections (engineering gates + success
   metrics), marked medium-confidence inference. The human should confirm the
   synthesis matches intent before the constitution leaves `draft`.

Neither question blocks the ADR-0003..0006 promotion proposed here; they gate only
the constitution/context/PRD documents.

## Proposed decision (for the human to record)

All four ADRs are internally consistent, and every mechanically-checkable claim was
confirmed against the committed tree (with the two minor phrasing notes above).
I **propose promotion of ADR-0003..0006 from `draft` to `active`**, with the caveats
recorded. Canonical readiness is not proposed for any of them yet: ADR-0004 and
ADR-0006 encode operational set-ups that Phase 4 hardening may still reshape, and
ADR-0003/0005 should season as `active` through at least one more consuming change.

To record an affirmative decision, the human sets `status: active` on each ADR
(patch-level version bump) and records the decision; this file plus the promoting
commit message are the retrievable record. Partial promotion (e.g. holding one ADR
back) is equally recordable.

**Until that recorded human decision, all four remain `draft`.** The agent does not
set `status`.

## Outcome (to be recorded by the human)

Not yet recorded. This section is intentionally empty until the non-author reviewer
adjudicates the evidence above and records the decision here.
