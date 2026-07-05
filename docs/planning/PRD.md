---
id: PRD-ephemeral-gitops-idp
title: Ephemeral GitOps IDP (Local Edition)
status: draft
version: 1.1.0
date: 2026-07-05
---

# Product Requirements Document (PRD)

**Project:** Ephemeral GitOps IDP (Local Edition)
**Target Environment:** Ubuntu 26.04 Workstation
**Status:** Spike in progress - blocked on a working CAPD+Talos cluster template (see Section 6)

This PRD synthesizes the requirements, the structural decision to use a management-cluster-driven GitOps workflow, and the state of the spike test.
It was revised on 2026-07-05 following a zoom-out review (`ZOR-ephemeral-gitops-idp-2026-07-05.md`) that corrected drift between the original draft and the implementation.
The load-bearing corrections are recorded inline and summarized in Section 7.

## 1. Introduction

This project delivers a deterministic, high-speed ephemeral Kubernetes environment.
It enables developers to provision production-identical Talos Linux clusters locally.
By using a "bootstrap-to-target" architecture, the system reuses the same GitOps workflow that will later drive cloud-based Cluster API (CAPI) deployments, while keeping local secrets off Git via SOPS/AGE.

The parity this buys is precise, and Section 5 states its boundary: the workflow and the application/workload manifests are shared across providers; the cluster-provisioning manifests are not.
Overstating parity is the main way this project can disappoint, so the boundary is stated as a first-class requirement rather than an aspiration.

## 2. Technical Architecture

The platform operates on a two-cluster model:

1. **Management Plane (`kind`):** A lightweight ephemeral cluster on the host workstation (inside the devcontainer's Docker).
   It runs the CAPI core, the CAPD (Docker) infrastructure provider, and the Talos bootstrap/control-plane providers (CABPT/CACPPT).
2. **Target Plane (Talos Linux):** The workload cluster, provisioned as Talos nodes running in Docker containers by CAPD, managed declaratively by the Management Plane.
3. **Bootstrap Security:** A `mise` task orchestrates SOPS/AGE secret decryption and injects the identity into the Management Plane.

Note on the management-cluster runtime: the management plane is `kind`, not `k3d`.
The repository name, every `mise` task, and the live spike cluster use `kind`; the earlier draft's `k3d` reference was leftover drift and has been removed.

## 3. Core Requirements

### 3.1 Provisioning Flow (The "Turnkey" Pipeline)

* **Initialization:** `mise` triggers the bootstrap.
  The system checks for the management cluster; if absent, it creates the `kind` cluster and runs `clusterctl init`.
* **Identity Injection:** The AGE-backed SOPS secret is decrypted and applied as a native K8s secret in the management plane.
* **GitOps Reconciliation:** FluxCD (running in the management plane) reconciles the target cluster manifests, instructing CAPI/CAPD to provision the Talos nodes.
* **Self-Configuration:** Once the Talos nodes boot, a secondary FluxCD instance (in the target cluster) applies the "turnkey" payload:
* **Networking:** Cilium (eBPF-native CNI/L4-LB, no kube-proxy).
* **Traffic:** Cloudflare Tunnel for secure ingress.
* **Identity:** Dex (OIDC) integration.
* **Management:** Cert-manager with local Root CA.

The dual-Flux design (one loop in the management cluster reconciling infrastructure, one in the target cluster reconciling apps) is a deliberate cost.
Its entire payoff is workflow parity with the future cloud pipeline (Section 5).
If that parity is ever descoped, revisit whether a single-loop or non-CAPI local path is cheaper (Section 6, pivot indicators).

### 3.2 Security

* **No plaintext secrets in Git:** No decrypted credentials are committed.
  The project AGE key lives at `.config/sops/age/keys.txt` and is gitignored.
* **v1 posture (accepted):** Decryption uses a software AGE key on disk (gitignored), with the user key as a co-recipient so `mise` can auto-decrypt.
  This is the accepted posture for the local ephemeral environment and does not block the spike or the pipeline.
* **Hardening milestone (later, not v1):** Move decryption to a hardware-bound key via `age-plugin-yubikey`, so the private key never exists in plaintext on disk and decryption blocks on a physical YubiKey touch.
  This was originally written as a v1 hard requirement; it is reclassified here as a follow-on hardening milestone to avoid blocking the pipeline on hardware key provisioning.

### 3.3 Idempotency & Lifecycle

* **Deterministic Teardown:** The system must provide a clean teardown that deletes the `kind` management cluster, prunes the CAPD Docker containers/networks for the target cluster, and removes local config state (`.kube-*.config`, `.talosconfig`).
* **Reconciliation:** All infrastructure state is declarative.
  Re-running the bootstrap task must result in no change if the desired state is already reached.

## 4. Engineering Gates (From Spike Test)

The following validation gates must pass in the spike before the full pipeline is built, and must remain active in the automation pipeline afterwards:

1. **Cilium/eBPF Compatibility:** Cilium pods reach `Running` (no `CrashLoopBackOff` from BPF mount failures) inside the CAPD Docker containers.
2. **Cross-Pod Connectivity:** Pod-to-pod routing via Cilium works across nodes.
3. **L4 Service Allocation:** Cilium dynamically assigns a `LoadBalancer` IP, reachable from the Ubuntu host.

Version alignment for these gates (corrected 2026-07-05):

* Cilium must be on a maintained line (1.17/1.18/1.19); 1.15 is end-of-life and supports only Kubernetes 1.26-1.29.
* The Kubernetes version must sit inside the chosen Cilium line's tested matrix.
  Cilium 1.19 is e2e-tested against Kubernetes 1.32-1.35; the spike therefore pins Kubernetes 1.35.x with Cilium 1.19.x.
  Talos 1.13.x supports this range.

## 5. Parity: what is and is not identical across providers

This section replaces the earlier unqualified "manifests must be identical to AWS" claim.

* **Identical across providers (the real parity win):**
  the GitOps workflow itself, and the application/workload overlay - Flux `Kustomization` objects, Cilium/cert-manager/Dex `HelmRelease`s, and app `Deployment`s.
  These carry over to CAPA (AWS) untouched.
* **Provider-specific (not identical), by design:**
  the cluster-provisioning base - the `infrastructureRef` targets (`DockerCluster`/`DockerMachineTemplate` locally vs `AWSCluster`/`AWSMachineTemplate` on AWS) and the Talos `configPatches` (container CNI/disk/kernel locally vs EC2 cloud-provider/metadata/real load balancer on AWS).
* **No upstream CAPD+Talos template exists:**
  the maintained Sidero template collection ships `aws` and `gcp` only; the Docker infrastructure provider is kubeadm-default.
  The local Docker+Talos template is therefore a bespoke artifact this project authors and maintains, with no maintained AWS counterpart to be byte-identical to.
  The parity contract is "same workflow and same app overlay," not "same infrastructure manifests."

## 6. Spike status and Open Questions

* **Spike status (blocked):**
  `clusterctl init` succeeds and all controllers (capi, capd, cabpt, cacppt, cert-manager) run, but no `Cluster`/`Machine` resources get created because `clusterctl generate cluster --flavor talos --infrastructure docker` does not resolve to a template - the Docker provider ships no `talos` flavor.
  Next action: author a bespoke CAPD+Talos template (`DockerCluster` + `DockerMachineTemplate` for infra; `TalosControlPlane` + `TalosConfigTemplate` for bootstrap/control plane) and set `cni: { name: none }` plus `proxy: { disabled: true }` via `configPatches` in the template, so nodes boot ready for Cilium's kube-proxy replacement.
  The CNI/proxy disable must be a template `configPatch`, not a post-hoc `talosctl patch` - a post-hoc patch fights CAPI reconciliation.
* **State Persistence:** Determine the strategy for local volume snapshotting if ephemeral cluster development requires "re-hydrating" database state across reboots.
* **Overlay Strategy:** Finalize the Kustomize overlay structure so that moving from CAPD to CAPA changes only the infrastructure/Talos base (Section 5), leaving the workload overlay untouched.

## 7. Success Metrics

* **Spin-up Time:** < 10 minutes from `mise` command to turnkey cluster readiness.
* **Workflow & app-overlay parity:** the GitOps workflow and the application/workload overlay for the target cluster are identical to the future AWS (CAPA) deployment.
  The infrastructure/Talos base is explicitly provider-specific and is not measured for byte-identity (Section 5).
* **Cleanliness:** Zero orphaned Docker containers/networks after `teardown`.

## 8. Zoom-out corrections applied (2026-07-05)

* Management plane standardized on `kind` (was `k3d` in the draft; drift from the implementation).
* YubiKey/zero-plaintext reclassified from a v1 hard requirement to a follow-on hardening milestone; the software AGE-key posture is the accepted v1 (Section 3.2).
* Parity claim scoped to workflow + app overlay; the infrastructure/Talos base is acknowledged as provider-specific with no upstream CAPD+Talos template (Section 5, Success Metric 2).
* Spike version pins corrected: Cilium 1.15 (EOL) to 1.19.x, Kubernetes 1.36.2 to 1.35.x, to stay inside the tested compatibility matrix (Section 4).
* Spike status recorded honestly as blocked on the missing CAPD+Talos template, with the CNI/proxy `configPatch` requirement called out (Section 6).

---

### Next Steps for Implementation

1. **Author the CAPD+Talos template** and get the spike to green (all three gates in Section 4).
2. **Repository Setup:** Configure the directory structure (`clusters/management` and `clusters/workload`) for Flux, with the app overlay separated from the provider-specific infrastructure base (Section 5).
3. **Secret Management:** Keep the software AGE key for v1; schedule the `age-plugin-yubikey` hardening milestone (Section 3.2).
