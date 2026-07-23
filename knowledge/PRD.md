---
id: PRD
title: Ephemeral GitOps IDP (Local Edition) - Product Requirements
status: draft
version: 1.5.2
date: 2026-07-22
type: prd
---

# Product Requirements Document (PRD)

> Inducted into the governed knowledge base from `docs/planning/PRD.md` on
> 2026-07-22, resolving the constitution's PRD-induction open question (RFC-003
> minimal artifact set).
> This is the authoritative, governed version (`type: prd`); the copy under
> `docs/planning/PRD.md` is retained as the ungoverned working original.
> Cross-references below to `PLAN-*`, `ZOR-*`, and the two dated planning ADRs
> (`ADR-capd-*`, `ADR-cilium-*`) name files under `docs/planning/`.

**Project:** Ephemeral GitOps IDP (Local Edition)
**Target Environment:** Ubuntu 26.04 Workstation
**Re-framed:** 2026-07-06 - local v1 provisions Talos via `talosctl cluster create` (Docker provisioner) with a single Flux loop; all CAPI machinery is deferred to the cloud milestone (Section 6, `docs/planning/ZOR-ephemeral-gitops-idp-2026-07-06.md`)

This PRD synthesizes the requirements, the structural decisions, and the state of the spike test.
It was revised on 2026-07-05 after a zoom-out review (`ZOR-ephemeral-gitops-idp-2026-07-05.md`) and re-framed on 2026-07-06 after a second zoom-out review (`ZOR-ephemeral-gitops-idp-2026-07-06.md`) triggered by a live-probe finding that falsified the original architecture's core premise.
The load-bearing corrections are recorded inline and summarized in Sections 8-10.

## 1. Introduction

This project delivers a deterministic, high-speed ephemeral Kubernetes environment.
It enables developers to provision Talos Linux clusters locally, running the same GitOps workflow and application overlay that will later drive cloud-based Cluster API (CAPI) deployments, while keeping local secrets off Git via SOPS/AGE.

The parity this buys is precise, and Section 5 states its boundary: the workflow and the application/workload manifests are shared across environments; the cluster-provisioning mechanism is not.
Overstating parity is the main way this project can disappoint, so the boundary is stated as a first-class requirement rather than an aspiration.

## 2. Technical Architecture

The v1 platform operates on a single-cluster local model:

1. **Target Cluster (Talos Linux in Docker):** provisioned directly by `talosctl cluster create` (the Docker provisioner - Sidero's primary local quickstart path), with one control-plane and two worker nodes.
   Two workers because engineering gate 2 (Section 4) must provably cross a node boundary: Talos control-plane nodes are `NoSchedule`-tainted by default, so a single-worker topology would let both test pods land on one node and pass the gate vacuously.
   The stock CNI and kube-proxy are disabled via a Talos config patch so Cilium can own both.
2. **GitOps Loop (single, in-cluster):** one FluxCD instance inside the target cluster reconciles the turnkey payload from this repository's `clusters/workload/` tree.
3. **Bootstrap Security:** a `mise` task orchestrates SOPS/AGE secret decryption and injects the AGE key as the `sops-age` secret into the target cluster's `flux-system` namespace, so Flux's kustomize-controller can decrypt SOPS-encrypted manifests.
4. **Deferred management plane (Milestone M-CAPI in the plan):** the CAPI management cluster, the Talos bootstrap/control-plane providers (CABPT/CACPPT), and the second Flux loop return when a real cloud (CAPA) target exists.
   The original local design (kind management cluster + CAPD provisioning Talos containers) was falsified by live probe: CAPD's `DockerMachine` controller can only exec kubeadm-style bootstrap scripts and cannot consume Talos machine configs (Section 6).

The single-loop design is the deliberate v1 shape, not a compromise made in passing.
The 2026-07-06 zoom-out established that the parity worth buying locally is the Flux workflow plus the application overlay, both of which survive without a locally CAPI-managed target; the dual-loop rehearsal would have run against a throwaway, provider-specific base that no supported local CAPI provider can supply under the project's Docker-only constraint.

## 3. Core Requirements

### 3.1 Provisioning Flow (The "Turnkey" Pipeline)

* **Initialization:** `mise` triggers the bootstrap.
  The system checks for the target cluster; if absent, it creates it via `talosctl cluster create` with the CNI/proxy-disabling config patch.
  Because no CNI is present at creation time, node readiness is deliberately not gated at this step (nodes only report Ready once a CNI runs); the pipeline instead waits for the Kubernetes API to serve and proceeds.
* **CNI Bootstrap (imperative by necessity):** Cilium is installed imperatively via Helm immediately after cluster creation.
  This cannot be Flux's job: Flux's controllers are ordinary pod-network `Deployment`s and cannot start on a CNI-less cluster, so the GitOps loop can never deliver its own network.
  Flux subsequently adopts the release: the payload's `HelmRelease` uses the same release name and namespace and must pin the same chart version and values as the bootstrap install, so the first reconcile is a no-op upgrade - a divergent first upgrade would restart the CNI underneath the very controller performing it.
  Whether helm-controller takes over a CLI-installed release cleanly is Flux-version-dependent; it is verified live in plan Phase 2, not assumed.
  After adoption, day-2 Cilium changes flow through Git.
* **GitOps Reconciliation:** FluxCD's controllers are installed into the target cluster (creating the `flux-system` namespace).
* **Identity Injection:** the AGE-backed SOPS key is decrypted and applied as the `sops-age` secret into `flux-system`, and the persistent read-only deploy key (Section 6) is applied as the `git-credentials` secret - both after the Flux install creates the namespace, and before the root `Kustomization` is applied, so decryption and Git authentication never race the first reconcile.
* **Self-Configuration:** the `GitRepository` and root `Kustomization` are applied, and Flux reconciles the "turnkey" payload from `clusters/workload/`:
  * **Networking:** Cilium (eBPF-native CNI/L4-LB, no kube-proxy; adopted from the bootstrap install).
  * **Traffic:** Cloudflare Tunnel for secure ingress.
  * **Identity:** Dex (OIDC) integration.
  * **Management:** cert-manager with local Root CA.

### 3.2 Security

* **No plaintext secrets in Git:** no decrypted credentials are committed.
  The project AGE key lives at `.config/sops/age/keys.txt` and is gitignored.
* **v1 posture (accepted):** decryption uses a software AGE key on disk (gitignored), with the user key as a co-recipient so `mise` can auto-decrypt.
  This is the accepted posture for the local ephemeral environment and does not block the spike or the pipeline.
* **Hardening milestone (later, not v1):** move decryption to a hardware-bound key via `age-plugin-yubikey`, so the private key never exists in plaintext on disk and decryption blocks on a physical YubiKey touch.
  This was originally written as a v1 hard requirement; it is reclassified as a follow-on hardening milestone to avoid blocking the pipeline on hardware key provisioning.

### 3.3 Idempotency & Lifecycle

* **Deterministic Teardown:** the system must provide a clean teardown that destroys the Talos cluster (`talosctl cluster destroy`), prunes the Docker containers and the cluster's Docker network, and removes local config state (`.kube-*.config`, `.talosconfig`).
  Teardown must also verify zero residue in user-global state: no cluster context left in `~/.kube/config` or `~/.talos/config`, and no leftover `talosctl` cluster state directory.
  `talosctl` merges contexts into the global configs unless the invocation is scoped, so provisioning scopes its outputs to the repo-local paths (the exact `talosctl` mechanism - env, flags, or a separate `--merge=false` retrieval - is verified at implementation time) and teardown verifies the invariant rather than assuming it.
* **Idempotent lifecycle, two regimes stated honestly:**
  * Cluster existence is imperative but idempotent: re-running the bootstrap task against an already-correct cluster is a no-op, and every operation detects its actual precondition and self-heals rather than sleeping or silently skipping (the standing idempotency bar).
  * Everything inside the cluster is declarative: Flux reconciles the payload continuously from Git.
  The earlier draft claimed "all infrastructure state is declarative"; under the re-frame that claim is scoped to in-cluster state, since local cluster provisioning is a `talosctl` invocation, not a manifest.
  Fully declarative cluster provisioning returns with CAPI at the cloud milestone.

## 4. Engineering Gates (From Spike Test)

The following validation gates must pass in the spike before the full pipeline is built, and must remain active in the automation pipeline afterwards:

1. **Cilium/eBPF Compatibility:** Cilium pods reach `Running` (no `CrashLoopBackOff` from BPF mount failures) inside the Talos Docker containers.
2. **Cross-Pod Connectivity:** pod-to-pod routing via Cilium works across nodes, with the test pods verified to sit on different nodes (a spread constraint plus a node-name assertion) - otherwise the gate can pass vacuously on a single schedulable node.
3. **L4 Service Allocation:** Cilium dynamically assigns a `LoadBalancer` IP, reachable from the Ubuntu host.
   Allocation and reachability are separate mechanisms: Cilium's LB-IPAM assigns nothing without a `CiliumLoadBalancerIPPool` (pod-side `ipam.mode` is unrelated to service IPs), and reachability from the host additionally requires announcement (a Cilium L2 announcement policy) or a host route toward the pool (plan, Phase 0).

Version alignment for these gates (corrected 2026-07-05; risk noted 2026-07-06):

* Cilium must be on a maintained line (1.17/1.18/1.19); 1.15 is end-of-life and supports only Kubernetes 1.26-1.29.
* The Kubernetes version must sit inside the chosen Cilium line's tested matrix.
  Cilium 1.18 and 1.19 are both e2e-tested against Kubernetes 1.32-1.35; the spike pins Kubernetes 1.35.x, originally with Cilium 1.19.x, corrected to 1.18.11 below.
  Talos 1.13.x supports this range.
  (Matrix and EOL-range claims were checked against upstream compatibility docs during the 2026-07-05 review; re-verified live at Phase 0 implementation.)
* **1.19.x pin fallback triggered and confirmed (2026-07-06):** cilium/cilium#46010's symptom reproduced live on Phase 0's first clean run - Cilium 1.19.5 with `kubeProxyReplacement=true` on Talos 1.13.5 broke host-network DNS resolution cluster-wide (containerd image pulls and even `hostNetwork: true` pods timed out resolving through the node's own embedded resolver), while the Kubernetes API and pod-to-pod networking kept working, so `kubectl` alone did not surface it.
  Cilium 1.18.11 on a freshly re-provisioned cluster (not a version downgrade on the same nodes - stale eBPF/iptables state from the 1.19.5 agent survives `helm uninstall`) showed no such symptom across two full teardown/re-provision cycles.
  **Pin corrected to Cilium 1.18.11** for v1; see ADR (`ADR-cilium-1-19-kubeproxyreplacement-talos-host-networking-2026-07-06.md`).

## 5. Parity: what is and is not identical across environments

This section replaces the earlier unqualified "manifests must be identical to AWS" claim, and was re-scoped on 2026-07-06.

* **Identical across environments (the real parity win):**
  the GitOps workflow itself, and the application/workload overlay - Flux `Kustomization` objects, Cilium/cert-manager/Dex `HelmRelease`s, and app `Deployment`s.
  These carry over to the future cloud (CAPA) deployment untouched.
* **Environment-specific (not identical), by design:**
  the cluster-provisioning mechanism.
  Locally in v1 this is an imperative, idempotent `talosctl cluster create` invocation with a Talos config patch; on cloud it will be declarative CAPI manifests (`AWSCluster`/`AWSMachineTemplate` plus `TalosControlPlane`/`TalosConfigTemplate`) reconciled by a management cluster.
  There are no local CAPI manifests in v1 at all.
* **The CAPI-consumability contract (guards the boundary):**
  the workload overlay must never assume how the cluster was provisioned - no references to `talosctl`-specific names, node labels, or local paths that a CAPI-provisioned cluster would lack.
  This contract is what keeps the deferred CAPI milestone a bolt-on rather than a rewrite, and it gets a doubt-driven-development review when the overlay is first built (see the plan, Phase 2).
* **Historical note:** the 2026-07-05 draft planned a bespoke local CAPD+Talos template because no upstream one exists.
  The live probe subsequently showed why none exists: the combination is architecturally impossible, not merely unshipped (Section 6).

## 6. Spike status and Open Questions

* **Phase 0 green (2026-07-06):** all three engineering gates (Section 4) pass on `talosctl cluster create` (Docker provisioner, 1 control plane + 2 workers) with Cilium 1.18.11, reproducibly across two full `teardown` -> `setup` -> `validate` cycles (proving both the happy path and idempotent re-entry).
  Baseline stage timings (cold, no image cache warm-up beyond what Docker already retained): `provision` ~160-195s, `cilium` (install/upgrade + agent restart + LB pool/L2 policy) ~80s, `validate` (all 3 gates) ~50-65s; total ~5-6 minutes from a clean `teardown`.
  This is a Phase 0 baseline only, not a Success-Metric-1 pass/fail - that target is defined against full turnkey-payload readiness, which does not exist until Phases 2-3.
  Gate 3 required both a `CiliumLoadBalancerIPPool` (10.5.0.240/28, a sub-block of the Docker bridge subnet the node IPs never reach) and a `CiliumL2AnnouncementPolicy` (`^eth0$`, the host shares the same L2 segment as the Docker bridge so ARP announcement alone is sufficient - no separate host route needed).
  A second gotcha surfaced independently of the version pin: `helm upgrade` changes to agent-level Cilium flags (e.g. `enable-l2-announcements`) update the ConfigMap but the chart carries no config-checksum annotation to roll the agent DaemonSet, so already-running agents keep stale flags until explicitly restarted (`kubectl rollout restart daemonset/cilium`) - the `cilium` task now does this unconditionally after every install/upgrade.
* **Spike status (re-framed 2026-07-06 - substrate decision resolved):**
  the CAPD blocker chain is closed by decision, not by fix.
  The full evidence and comparative logic live in `ZOR-ephemeral-gitops-idp-2026-07-06.md`; the plan (`PLAN-ephemeral-gitops-idp-2026-07-05.md`, v0.3+) carries the re-framed Phase 0.
  Summary of the falsification: the bespoke CAPD+Talos template was authored, its JSON6902 `configPatches` were fixed to Talos `strategicPatches` (confirmed live - `BootstrapConfigReady` reached `True`), and the next failure was architectural - CAPD's `DockerMachine` controller unconditionally execs bootstrap data as a kubeadm join script (`invalid character 'v' looking for beginning of value` while JSON-decoding Talos's YAML).
  No template change can fix a controller code path; Sidero documents no Docker+CAPD combination anywhere; the one CAPI provider with a Talos template (`cluster-api-provider-incus`) is CI-untested, VM-based, and violates the project's Docker-only constraint.
  The 2026-07-06 zoom-out interview then established: CAPI locally was a means to workflow parity (not a terminal goal), Talos-in-Docker fidelity suffices for v1, and Docker-only is a hard host-dependency line.
  Verdict: re-frame to `talosctl cluster create` + single-loop Flux, defer CAPI to Milestone M-CAPI (plan).
* **Superseded spike findings (audit trail):**
  * 2026-07-05: spike blocked on the missing CAPD+Talos template (`clusterctl generate --flavor talos --infrastructure docker` resolves to nothing).
    A bespoke template was authored in response.
  * 2026-07-06 (morning): template patches fixed, then the CAPD bootstrap-exec incompatibility surfaced and was briefly framed as a two-option substrate decision (drop CAPD vs swap to Incus).
    The zoom-out later that day resolved it as above.
* **Phase 2 green (2026-07-07):** `clusters/workload/` stands up the declarative in-cluster Flux loop - `flux-system/` (Flux controllers + `GitRepository`/root `Kustomization`) and `infrastructure/cilium/` (`HelmRepository`/`HelmRelease` adopting the Phase 0 bootstrap task's imperative Cilium install in place).
  Live-verified end-to-end three times from a clean `teardown` (see `PLAN-ephemeral-gitops-idp-2026-07-05.md` Phase 2 for the full evidence trail, including two real bugs a doubt-driven-development review and live testing caught and fixed: a values-file duplication that silently violated the single-source-of-truth precondition, and a server-side-apply field conflict between Helm CLI and helm-controller on re-entry after adoption).
  The CAPI-consumability contract (Section 5) is now a checkable doc at `clusters/workload/README.md`, not just this section's prose.
* **State Persistence:** determine the strategy for local volume snapshotting if ephemeral cluster development requires "re-hydrating" database state across reboots.
* **Flux source and local iteration loop (resolved 2026-07-07):** Flux tracks this repository's GitHub remote (confirmed private) via a persistent, one-time read-only SSH deploy key; local iteration on uncommitted changes uses a scratch branch the `GitRepository` tracks, repointed via `kubectl patch` and back to `main` when done.
  Full rationale in `clusters/workload/README.md` and the plan's Decisions section.
* **Overlay Strategy (resolved 2026-07-07):** the Kustomize layout is `clusters/workload/{flux-system,infrastructure}/`, with `infrastructure/kustomization.yaml` aggregating components so adding one doesn't require editing the root `kustomization.yaml`.
  Honors the CAPI-consumability contract; cleared a doubt-driven-development review (see the plan's Phase 2 status).

## 7. Success Metrics

* **Spin-up Time:** < 10 minutes from `mise` command to turnkey cluster readiness, where readiness means every payload `HelmRelease`/`Kustomization` reports `Ready`.
  The plan (Phase 4) carries a per-stage budget; if the measured total exceeds the target, the metric is renegotiated explicitly (scope or number), never silently missed.
* **Workflow & app-overlay parity:** the GitOps workflow and the application/workload overlay for the target cluster are identical to the future AWS (CAPA) deployment.
  The cluster-provisioning mechanism is explicitly environment-specific and is not measured for identity (Section 5).
* **Cleanliness:** zero orphaned Docker containers or networks for the cluster (including the `talosctl`-created cluster network), and zero config residue - no cluster context left in repo-local or user-global kubeconfig/talosconfig, no leftover `talosctl` state directory - after `teardown`.

## 8. Zoom-out corrections applied (2026-07-05)

* Management plane standardized on `kind` (was `k3d` in the draft; drift from the implementation).
* YubiKey/zero-plaintext reclassified from a v1 hard requirement to a follow-on hardening milestone; the software AGE-key posture is the accepted v1 (Section 3.2).
* Parity claim scoped to workflow + app overlay; the infrastructure/Talos base acknowledged as provider-specific with no upstream CAPD+Talos template (Section 5).
* Spike version pins corrected: Cilium 1.15 (EOL) to 1.19.x, Kubernetes 1.36.2 to 1.35.x, to stay inside the tested compatibility matrix (Section 4).
* Spike status recorded honestly as blocked on the missing CAPD+Talos template.

## 9. Corrections applied (2026-07-06, pre-re-frame)

* Spike status revised: the missing-template blocker was resolved (bespoke template authored, `strategicPatches` fix confirmed live), exposing the CAPD bootstrap-exec incompatibility underneath.
* The finding was classified as a pending substrate decision rather than resolved unilaterally.

## 10. Re-frame applied (2026-07-06, post-zoom-out)

Per `ZOR-ephemeral-gitops-idp-2026-07-06.md` (verdict: re-frame recommended, confidence high):

* v1 architecture changed from dual-cluster (kind management + CAPD-provisioned Talos target, dual Flux) to single-cluster (`talosctl`-provisioned Talos target, single in-cluster Flux).
* All CAPI machinery (management cluster, CAPD/CABPT/CACPPT, the outer Flux loop) deferred to Milestone M-CAPI (plan); the PRD's own pivot clause (former Section 3.1) anticipated exactly this case.
* Parity contract restated as workflow + app overlay, guarded by the CAPI-consumability contract (Section 5).
* Declarative-infrastructure claim honestly re-scoped to in-cluster state (Section 3.3).
* Cilium 1.19.x risk (cilium/cilium#46010) recorded with an explicit fallback trigger (Section 4).

---

### Next Steps for Implementation

1. **Done (2026-07-06).** Rewrote the spike tasks around `talosctl cluster create` and drove the three Section 4 gates to green (plan, Phase 0).
2. **Done (2026-07-07).** Built `clusters/workload/` for Flux with the overlay honoring the CAPI-consumability contract (plan, Phase 2).
3. **Secret Management:** keep the software AGE key for v1; schedule the `age-plugin-yubikey` hardening milestone (Section 3.2).
