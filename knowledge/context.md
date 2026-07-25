---
id: context
title: Ephemeral GitOps IDP (Local Edition) - Context
status: active
version: 0.2.4
date: 2026-07-24
type: context
---

# Context - Ephemeral GitOps IDP (Local Edition)

A combined system-patterns / technical-context / product-context document, per the
discovery instruction set section 4 (at most one combined context document).
Every claim is cited or marked as an inference.

## Product context

The project's sole user is its own author, operating a single Ubuntu 26.04 workstation
(`docs/planning/PRD.md` header, line 12).
Every accepted security/operational gap in the repository is justified in these terms -
"single-user local dev tool" or "single-developer local dev tool" - and each is flagged
to be revisited only if the tool ever serves more than one person
(`clusters/workload/README.md` lines 87-89, 119-129).

The product itself is a local, ephemeral, GitOps-managed Kubernetes environment used as
a development rehearsal for a future cloud (CAPA/AWS) deployment: the workflow and
application-overlay carry over, the provisioning substrate does not
(`README.md` lines 1-8; `docs/planning/PRD.md` Section 5).

## Technical context (stack and pinned versions)

- **Cluster substrate:** Talos Linux, provisioned by `talosctl cluster create`'s Docker
  provisioner (1 control-plane + 2 workers), Kubernetes 1.35.x
  (`docs/planning/PRD.md` Section 2, lines 29-33).
  No CAPI/CAPD in v1 - see ADR-0001.
- **CNI:** Cilium **1.18.11** (not 1.19.x - see ADR-0002), eBPF-native, no kube-proxy
  (`kubeProxyReplacement=true`), KubePrism as the in-cluster API endpoint
  (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` lines 61-63).
  Installed imperatively first (Flux cannot deliver its own CNI prerequisite), then
  adopted in place by a Flux `HelmRelease` with matching name/namespace/version/values
  (`docs/planning/PRD.md` Section 3.1, lines 49-53).
- **GitOps:** FluxCD, pinned to `2.9.0` because its Cilium-adoption reconcile behavior
  is version-dependent (`.config/mise/config.toml` line 61).
  A single in-cluster Flux instance reconciles `clusters/workload/`
  (`README.md` line 34).
- **Secrets:** SOPS + AGE.
  Software AGE key for v1 (gitignored, at `.config/sops/age/keys.txt`), user key as a
  co-recipient for auto-decrypt; `mise`'s SOPS integration is set to fail loudly on
  decryption failure (`sops.strict = true`, `.config/mise/config.toml` line 44).
  Hardware-bound (YubiKey) key is a deferred hardening milestone
  (`docs/planning/PRD.md` Section 3.2).
- **Task orchestration:** `mise`, host-native on the laptop (ADR-0003).
  A `.devcontainer/` consuming the shared `devbase` image (thin Dockerfile that
  adds a Docker CLI) was added for cross-machine dev and agent sessions on a
  second host, reopening ADR-0003 per its own revisit trigger (ADR-0006).
  Its default container is a plain sandbox with no Docker access; the
  host-root-equivalent Docker socket and host networking that `talosctl` needs
  live in an opt-in `compose.cluster.yaml` overlay used only on a cluster-run
  host, so unattended agent sessions on the VPS never hold that access.
  The cluster itself still runs on the laptop, since a 4GB second host cannot
  hold the ~6GB Talos cluster.
  Every tool version is pinned in `.config/mise/config.toml`'s `[tools]` table
  (age, bats, flux2, git-cliff, hadolint, helm, jq, kubectl, lefthook, lychee, sops,
  talosctl, vale, yq).
- **Git hooks:** Lefthook, regenerating `docs/CHANGELOG.md` and running lint and
  SOPS/secrets-leak guards before every commit (`README.md` line 79;
  `.config/lefthook.yaml`).
- **Prose linting:** vale and markdownlint, enforcing this project's own documentation
  conventions - no em dashes, one sentence per line
  (`README.md` line 81; `.config/vale/`, `.config/markdownlint/`).
- **Changelog:** git-cliff, generating `docs/CHANGELOG.md` from Conventional Commits;
  explicitly never hand-edited (`README.md` line 39; `.config/cliff.toml`).
- **Turnkey payload components** (all Flux-reconciled under `clusters/workload/`):
  - cert-manager `v1.20.3` with a local Root CA issuer chain
    (`selfsigned` -> `root-ca` -> `local-ca`)
    (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` lines 139-141).
  - Dex `dexidp/dex@0.24.1`, GitHub OIDC connector, TLS from the `local-ca`
    (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` line 149).
  - Cloudflare Tunnel (`cloudflared`), token-mode / `remote_config: true`
    (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` lines 149, 201-206).

## System patterns

- **The CAPI-consumability contract.** `clusters/workload/` must never reference how
  the cluster was provisioned: no `talosctl`-specific node names/labels, no local
  filesystem paths (`hostPath` or paths under a developer's home directory or working
  copy), and no reference to the Docker provisioner's network topology
  (`clusters/workload/README.md` lines 10-26).
  This is a checkable doc, not just prose - it received its own
  doubt-driven-development review (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md`
  lines 114-115).
- **Layered `controllers`/`configs` Kustomization pattern for CRD-provider
  components** (cert-manager), versus a flat single-`Kustomization` model for
  components without CRD-ordering needs (Cilium, Dex, Cloudflare Tunnel).
  See ADR-0005.
- **Aggregator pattern.** `infrastructure/kustomization.yaml` aggregates components so
  that adding one does not require editing the root `Kustomization`
  (`docs/planning/PRD.md` Section 6, line 144; found and fixed during the Phase 2
  doubt-driven-development review,
  `docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` line 115).
- **The idempotency bar.** Every operation in the imperative (cluster-existence) layer
  detects its actual precondition and self-heals, rather than sleeping or silently
  skipping; a fixed `sleep 15` in an earlier task revision was explicitly identified as
  below this bar and replaced with a retry-until-allocated loop
  (`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` lines 34-35, 65).
- **Bootstrap-imperative, day-2-declarative pattern.** Cilium's first install is
  imperative by necessity (Flux's own controllers need a working CNI to run); the
  in-tree `HelmRelease` then adopts that release in place so day-2 changes flow through
  Git (`docs/planning/PRD.md` Section 3.1, lines 49-53).
  This pattern is explicitly meant to generalize to any future CRD-provider bootstrap
  need (ADR-0005 consequences).
- **Persistent-credential, scratch-branch local iteration.** See ADR-0004: a
  persistent SSH deploy key (not per-cycle), and a scratch-branch repoint of the
  `GitRepository` for local iteration, chosen specifically to keep the Flux source
  *kind* identical between local and cloud.
- **Release-pinned upstream tracking.** RKA, `agent-standards`, and the
  `rka-template` conventions are consumed only at tagged releases, never at
  upstream HEAD (RKA ADR-0012 release trains).
  The current pin is `rka-template` v0.4.0 (verified 2026-07-22), and the
  `devbase` image is digest-pinned in `.devcontainer/Dockerfile`.
  One scoped exception stands: the RKA ADR-0013 spec-bundle lifecycle (validator
  rules 8, 9a, 9b) was adopted early on 2026-07-24 by maintainer decision, ahead
  of any `rka-template` release carrying it, because this repo was the upstream
  rules' motivating example (ADR-0009).
  The exception is scoped to ADR-0013 alone and carries a reconciliation
  obligation at the next release that ships those rules; ADR-0012 governs
  everything else.
- **Governed feature specs.** Feature specs live as governed bundles under
  `knowledge/specs/<NNN>-<slug>/` with `<role>-<NNN>-<slug>` ids, one shared
  `status` per bundle, and an `Extraction record` on archival (RKA ADR-0013 via
  ADR-0009). `docs/specs/` no longer exists.

## Known accepted gaps (v1, not solved by design)

All recorded directly in `clusters/workload/README.md` "Known limitations" (lines
91-129), each an explicit trade-off rather than an oversight:

- No day-2 config-drift restart for agent-level Cilium flags once Flux owns Cilium's
  day-2 changes (the imperative bootstrap task's unconditional `DaemonSet` restart has
  no Flux-side equivalent yet).
- `flux-system`'s `NetworkPolicies` allow unrestricted egress (inherited unmodified
  from `flux install --export`'s stock output), with the `git-credentials` and
  `sops-age` secrets living in that namespace.
- The Cloudflare Tunnel's ingress config is enforced by Cloudflare's control plane
  (API push), not Flux-reconciled, a structural consequence of the tunnel being
  provisioned with `remote_config: true` (token-mode `cloudflared`).
- `cloudflared`'s origin connection to Dex skips TLS verification
  (`noTLSVerify: true`), justified because the hop never leaves the cluster's pod
  network.
- Dex's GitHub connector has no `orgs:` restriction - any GitHub account can
  authenticate.

## Open question carried from the constitution

State-persistence / data re-hydration across ephemeral cluster cycles is unresolved
and explicitly deferred pending real need (`docs/planning/PRD.md` Section 6, line 141;
`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md` "Decisions - Open", lines
210-212).
