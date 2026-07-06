---
id: PLAN-ephemeral-gitops-idp
title: Implementation plan - Ephemeral GitOps IDP (Local Edition)
status: draft
version: 0.5.0
date: 2026-07-06
---

# Implementation plan - Ephemeral GitOps IDP

This plan sequences the work from the current state to the PRD's success metrics.
It is grounded in live probes of the running spike environment (2026-07-05 and 2026-07-06), not on assumptions, and was re-framed on 2026-07-06 per the zoom-out verdict in `ZOR-ephemeral-gitops-idp-2026-07-06.md`.
Read it alongside `PRD.md` v1.3+ (the spec) and both zoom-out reports.
(The filename keeps its original 2026-07-05 creation date as a stable identifier; the frontmatter `date` tracks the latest revision.)

## Architecture after the re-frame (one paragraph)

Local v1 is a single Talos-in-Docker cluster created by `talosctl cluster create`, with one Flux instance inside it reconciling the turnkey payload from `clusters/workload/`.
There is no local management cluster, no CAPI, and no second Flux loop; those return at the cloud milestone (Milestone M-CAPI below).
The parity that must survive is the Flux workflow and the application overlay, guarded by the CAPI-consumability contract (PRD Section 5).

## Current state (evidence-based)

What the two probe sessions established, and what carries forward:

- **FALSIFIED (2026-07-06, closes the CAPD line of work): CAPD cannot bootstrap Talos.**
  With the docker-socket mount, the provisioning races, and the patch format all fixed, CAPD's `DockerMachine` controller still fails unconditionally: it execs the bootstrap secret as a kubeadm join script and JSON-chokes on Talos's machine-config YAML (`invalid character 'v' looking for beginning of value`, confirmed in `capd-system` controller logs).
  This is controller code, not configuration; no further template or task changes can fix it.
  The substrate decision this raised was resolved by the 2026-07-06 zoom-out: re-frame to `talosctl`, defer CAPI.
- **Carries forward: the Talos config-patch content.**
  The `cluster.network.cni.name: none` + `cluster.proxy.disabled: true` strategic-merge patch authored for the CAPD template is exactly what `talosctl cluster create --config-patch` needs; only the delivery mechanism changes.
  (The JSON6902-to-strategicPatches finding is ADR material: Talos v1.13 machine configs are multi-document, and the Talos providers reject JSON6902 patches against them.)
- **Carries forward: the idempotency patterns and the mise env fix.**
  Detect-the-actual-precondition-and-self-heal (never fixed sleeps), `kubectl wait --for=create` for resources that appear asynchronously, and the `{{config_root}}` env-templating fix (Tera templating only applies in `config.toml`'s `[env]` table, not in plain dotenv files - `KUBECONFIG_*`/`TALOSCONFIG` moved accordingly).
  One exception is on record: the CAPD-era `validate` task contains a fixed `sleep 15` before a single-shot LoadBalancer-IP read, which is below this bar - it gets fixed in the Phase 0 rewrite, not carried forward.
- **Obsolete once Phase 0 is green - removed (2026-07-06):**
  `.config/capi/capd-talos-template.yaml`, the docker-socket kind config in `.config/kind/`, and the CAPD-specific wiring in the spike tasks.
  Git history and the ADRs preserve the knowledge.
- **Live state to clean up:** the `capi-test` kind management cluster (with the stuck `talos-cilium-test` workload objects) still runs from the probe sessions.
  It is torn down as the first step of Phase 0 (its own teardown task already handles this); it has no further diagnostic value now that the finding is recorded.

Nothing beyond the spike exists yet: there are no Flux manifests, no `clusters/` tree, no turnkey payload, and no `.devcontainer/`.

## Phase 0 - Get the spike to green on talosctl (unblocks everything)

**Status: done, green (2026-07-06).** All steps below landed as written except where noted inline; see `PRD.md` Section 6 for the baseline timings and both ADRs for the two findings that surfaced during implementation.

The PRD rests on "Cilium works inside locally provisioned Talos Docker containers."
Until the three engineering gates pass, no pipeline should be built on top.
Upstream evidence says this combination works (siderolabs/talos discussion #9849 confirms Cilium on the Docker provisioner, with a known sequencing workaround), but evidence is not a green gate; this phase produces one.

1. **Tear down the legacy CAPD environment** (one-time): run the existing teardown task to delete the `capi-test` kind cluster and prune the stuck workload containers.
2. **Rewrite the spike task chain around `talosctl`** (rename `test-capd-spike:*` to `test-talos-spike:*`; update any references):
   - `setup`: verify docker and `talosctl` availability (both mise-managed except docker); no management cluster to create anymore.
   - `provision`: idempotently create the target cluster:
     `talosctl cluster create` with `--name` from `$CLUSTER_NAME`, 1 control plane + 2 workers (gate 2 must provably cross a node boundary, and Talos control planes are `NoSchedule`-tainted by default), `--kubernetes-version` pinned to 1.35.x, and the CNI/proxy config patch via `--config-patch @<file>` (move the patch content from the CAPD template into a standalone `.config/talos/` patch file).
     **Correction (verified live, 2026-07-06):** no `--skip-k8s-node-readiness-check` flag exists in talosctl v1.13.5; `talosctl cluster create` auto-detects the CNI-disabled config patch and skips the node/kube-proxy/coredns readiness health-checks on its own, so no such flag is needed or passed.
     Scope config outputs to the repo-local `$KUBECONFIG_WORK`/`$TALOSCONFIG` paths and keep user-global configs clean - the exact mechanism needs verification at implementation time: `talosctl cluster create` merges a kubeconfig context into the default location by default, so the candidates are the `KUBECONFIG` env/`--talosconfig` scoping it respects, or a separate `talosctl kubeconfig <path> --merge=false` retrieval; if the merge proves unavoidable, provision removes the global context it created, and teardown verifies none remains either way.
     Detect an already-running cluster and make re-runs a no-op (idempotency bar).
     Wait on "Kubernetes API serving", not node readiness.
   - `cilium`: install Cilium via Helm per Sidero's Cilium guide for Talos: `kubeProxyReplacement=true`, `ipam.mode=kubernetes`, KubePrism as the API endpoint (`k8sServiceHost=localhost`, `k8sServicePort=7445` - KubePrism is on by default in Talos 1.13; the kubeconfig-derived host:port used by the CAPD-era task points at a host-published port that pods inside the nodes cannot reach), plus the guide's Talos-specific security-context and cgroup values (`cgroup.autoMount.enabled=false`, `cgroup.hostRoot=/sys/fs/cgroup`, and the guide's explicit capability list - Talos forbids workload kernel-module loading, which is why Cilium's default capability set does not carry over).
     Apply the guide's values verbatim and verify them against the current guide at implementation time rather than trusting this paragraph.
     **Version pin corrected (2026-07-06):** planned as 1.19.5, but the step 3 fallback trigger below fired on the first clean run; shipped as 1.18.11 - see the Cilium ADR.
   - `validate`: the three gates, unchanged in what they verify, with two implementation fixes over the CAPD-era task:
     the cross-node gate schedules its two test pods on different nodes (topology spread constraint or anti-affinity) and asserts their node names differ before curling, and the LoadBalancer check replaces the current `sleep 15` plus single-shot IP read (a fixed sleep, below the idempotency bar) with a retry-until-allocated loop.
   - `teardown`: `talosctl cluster destroy --name $CLUSTER_NAME`, then verify zero residue: no orphaned containers or networks for the cluster (the Docker provisioner creates a named network), no `$CLUSTER_NAME` context in user-global kubeconfig/talosconfig, no leftover `talosctl` cluster state directory, and remove `.kube-*.config`/`.talosconfig`.
3. **Known-risk watchpoint for gate 1 - triggered (2026-07-06):** cilium/cilium#46010 reports Cilium 1.19.x + `kubeProxyReplacement` on Talos 1.13 killing host networking during BPF/veth init.
   The actual symptom differed from the pre-registered trigger (it surfaced one step later, as host-network DNS failure in gate 2's test workload, not as a gate 1 or node-readiness failure - `kubectl`/`cilium-dbg` health checks did not flag it), but the fallback held: Cilium 1.18.11 on freshly re-provisioned nodes cleared it across two full teardown/re-provision cycles.
   Outcome recorded in the PRD version-alignment section and the Cilium ADR (`ADR-cilium-1-19-kubeproxyreplacement-talos-host-networking-2026-07-06.md`).
4. **Gate 3 decision point (LB reachability strategy):** a `CiliumLoadBalancerIPPool` scoped to the cluster's Docker subnet is required, not a fallback - Cilium's LB-IPAM assigns `LoadBalancer` IPs only when a pool exists, and pod-side `ipam.mode` is unrelated to service IPs.
   The open question is only reachability: allocation alone is not reachability, so pair the pool with a Cilium L2 announcement policy or a host route toward the pool, whichever the probe shows the Docker bridge needs.
   Resolve empirically, record the answer.
5. **Exit criteria:** all three gates green from a clean `setup` through `validate`, reproducibly, twice in a row from `teardown` (proves both the happy path and idempotent re-entry); stage timings (cluster create, Cilium ready, gates) measured and recorded as the baseline for the Phase 4 spin-up budget.
   (The PRD's < 10 minute target is defined against full payload readiness, which does not exist until Phases 2-3 - Phase 0 records a baseline, not a pass/fail against that target.)
6. **After green (done):** the obsolete CAPD assets listed in Current state are deleted, and both ADRs are extracted (Cross-cutting below).

### Phase 0 assumptions and their cheap tests (resolved, 2026-07-06)

| Assumption | Evidence today | Cheap test | Outcome |
| --- | --- | --- | --- |
| Cilium runs on Talos-in-Docker | Upstream discussion #9849 (single-sourced) | Gate 1 itself | Confirmed |
| KubePrism endpoint works in the Docker provisioner | Talos 1.13 default; not probed here | Gate 1; fallback is the node-IP:6443 endpoint | Confirmed, no fallback needed |
| Cilium 1.19.5 is safe on Talos 1.13 | Contradicted by one closed upstream report | Gate 1 with the 1.18.x fallback trigger | Falsified - fallback triggered, shipped 1.18.11 (Cilium ADR) |
| LB IP reachable from host | Unprobed; the IP pool is mandatory for allocation, only the announcement mechanism is open | Gate 3 (L2 announcement policy vs host route) | Confirmed - L2 announcement policy sufficient, no host route needed |
| Cilium 1.19 e2e matrix covers Kubernetes 1.35; 1.15 EOL ranges | Upstream docs, checked 2026-07-05, not re-verified since | Re-check the upstream matrix when pinning chart versions | Confirmed for 1.18 too (PRD Section 4) |

## Phase 1 - Resolve the devcontainer gap (decision, simplified by the re-frame)

**Status: done (2026-07-06).**

- **Decision made: host-native `mise`, not a devcontainer.**
  The toolchain is fully mise-managed and the only Docker requirement is that `talosctl`'s provisioner reach a Docker daemon - a single daemon socket, not the DinD socket-mount topology that made a devcontainer subtle under CAPD.
  No devcontainer spec is needed for v1; revisit only if a concrete cross-machine reproducibility problem shows up later.
- **Dangling `.devcontainer` references resolved:** removed `setup:project` (`.config/mise/tasks/setup.toml`) and `test:devcontainer` (`.config/mise/tasks/test.toml`) outright rather than rewiring them - both files' entire content was the broken reference, both pointed at paths that never existed, and neither has a replacement need under host-native: `sops:project:generate-keypair` already covers the AGE key bootstrap `setup:project` was meant to provide, and there is no devcontainer configuration left to validate with a BATS suite.

## Phase 2 - GitOps repository structure (single loop)

Convert the imperative spike into the PRD's declarative in-cluster loop, and build the Kustomize layout that carries the parity contract.

1. Create `clusters/workload/` as the Flux-reconciled tree: the turnkey payload plus the Flux `Kustomization`/`GitRepository` objects themselves.
   No `clusters/management/` tree exists in v1; add it only at Milestone M-CAPI.
2. **Honor the CAPI-consumability contract (PRD Section 5):** the overlay must not reference `talosctl`-specific node names, labels, or local paths.
   Write the contract down as a short doc next to the overlay (`clusters/workload/README.md` or similar) listing what a CAPI-provisioned cluster will and will not provide.
3. Wire the bootstrap task: install Flux into the target cluster, inject the `sops-age` secret into `flux-system` (the namespace exists only after the Flux install; the secret must land before the root `Kustomization` so decryption never races), apply the `GitRepository` + root `Kustomization`.
   Add `flux` to the mise `[tools]` set with a pinned version first - it is not yet declared there, and the Cilium-adoption behavior in step 5 is Flux-version-dependent.
4. **Decision (blocks step 3's final shape): Flux source and local iteration.**
   Default assumption: Flux tracks this repository's GitHub remote (auth via deploy key if the repo is private - resolve repo visibility here).
   Named open question: how a developer tests uncommitted manifest changes against an ephemeral cluster - candidate answers are a scratch branch Flux tracks, `flux push artifact` to a local OCI registry, or offline `flux build kustomization` diffing.
   Pick one deliberately; do not let the answer emerge by accident.
5. **Bootstrap ordering (hard constraint, not a footnote):** Flux's controllers are ordinary pod-network `Deployment`s and cannot start on a CNI-less cluster, so Flux can never deliver the initial CNI.
   Cilium's first install therefore stays imperative in the bootstrap task (Phase 0's `cilium` step survives into the pipeline), and Flux adopts it: the payload's `HelmRelease` uses the same release name and namespace, so helm-controller upgrades the existing release in place instead of fighting it.
   Hard precondition: the `HelmRelease` pins the same chart version and values as the bootstrap install - keep one values file that both the bootstrap task and the `HelmRelease` reference - so the adoption reconcile is a no-op upgrade; a divergent first upgrade would restart the CNI underneath the controller performing it.
   Verify the adoption live (helm-controller taking over the CLI-installed release without a destructive re-install) as part of this phase's exit criteria; after adoption, day-2 Cilium changes flow through Git, never the bootstrap task.
6. **Exit criteria:** the same green gates as Phase 0, with the Cilium `HelmRelease` (and all subsequent in-cluster changes) delivered by Flux reconciliation from Git, and the Cilium adoption handover verified live.

Subject the Phase 2 module boundary (overlay layout + consumability contract) to a doubt-driven-development review before it stands - it is the load-bearing structural decision for parity.

## Phase 3 - Turnkey payload

Build the target-cluster self-configuration as Flux `HelmRelease`/`Kustomization` objects under `clusters/workload/`:

- Cilium (already managed by Flux since the Phase 2 adoption; listed for completeness).
- cert-manager with a local Root CA `ClusterIssuer`.
- Dex (OIDC).
- Cloudflare Tunnel for ingress.

Sequence these behind Flux `dependsOn` so Cilium and cert-manager settle before Dex and the tunnel.

**Exit criteria:** every payload `HelmRelease`/`Kustomization` reports `Ready`; cert-manager issues a certificate from the local Root CA `ClusterIssuer`; Dex serves its OIDC discovery document; the Cloudflare Tunnel reports a live connection (or an end-to-end request through it reaches an in-cluster service); and every SOPS-encrypted secret in the payload decrypts (zero `Kustomization` decryption failures).

## Phase 4 - Lifecycle, idempotency, and metrics

1. Make the bootstrap task idempotent end-to-end: a re-run with state already reached is a no-op (PRD 3.3); every step detects its precondition and self-heals (the standing bar from the spike work).
2. Harden teardown: `talosctl cluster destroy`, verify zero orphaned Docker containers, volumes, or networks for the cluster, remove `.kube-*.config`/`.talosconfig` (PRD Success Metric 3).
3. Measure spin-up time against the < 10 minute target, broken into stages (cluster create, Cilium ready, Flux ready, payload `Ready`), and record a per-stage budget (first measured in Phase 0; re-measure with the full Flux-driven pipeline).
   The likely blowout stages are the Flux-sequenced payload components (cert-manager, Dex, Cloudflare Tunnel).
   If the total exceeds 10 minutes, the named levers are, in order: a host-side pull-through registry cache the ephemeral nodes are configured to use (`talosctl cluster create` supports registry-mirror flags; per-node image caches die with the nodes, so pre-pulling into nodes buys nothing across cycles), relaxing `dependsOn` chains where safe, and only as a last resort renegotiating the PRD metric explicitly - never silently missing it.

## Phase 5 - Security hardening (deferred milestone)

Move SOPS/AGE decryption to a hardware-bound key via `age-plugin-yubikey`, so the private key never exists in plaintext on disk and decryption blocks on a physical touch (PRD 3.2).
This is explicitly not a v1 blocker; the software AGE-key posture ships first.

## Milestone M-CAPI - reintroduce CAPI when a real cloud target exists

Deliberately unscheduled; triggered by a real CAPA/cloud deployment getting planned, not by v1 completion.

- Scope when triggered: a management cluster (kind is fine again - managing cloud needs no docker-socket topology), CAPA + CABPT/CACPPT via `clusterctl init`, a `clusters/management/` tree with the declarative cluster-provisioning manifests, and the second Flux loop reconciling it.
- The workload overlay carries over untouched if the CAPI-consumability contract held - that is the payoff the contract buys, and the first thing to verify at this milestone.
- Leading indicators for revisiting earlier (from `ZOR-ephemeral-gitops-idp-2026-07-06.md`): a cloud target getting scheduled; any payload component proving impossible on the Docker provisioner; the Docker provisioner losing upstream support.

## Cross-cutting

- **Extract ADRs after Phase 0 green (done, 2026-07-06):** the CAPD/Talos bootstrap-exec incompatibility (`ADR-capd-talos-bootstrap-incompatibility-2026-07-06.md`, which also covers the JSON6902-vs-strategicPatches multi-document finding) and the Cilium 1.19-on-Talos host-networking break (`ADR-cilium-1-19-kubeproxyreplacement-talos-host-networking-2026-07-06.md`).
  The `{{config_root}}` mise templating gotcha and the idempotency bar are recorded inline (`.config/mise/config.toml`, `.config/mise/.env`, and this plan's "Current state" section) rather than as standalone ADRs - neither rises to a decision with rejected alternatives, so a dedicated ADR would be overhead.
- The Phase 2 overlay boundary gets a doubt-driven-development review before it stands (noted in Phase 2).
- **Update `README`/onboarding text (done, 2026-07-06):** the README no longer describes the dual-cluster CAPI architecture or asserts the YubiKey-backed v1 security posture; it reflects the single-cluster `talosctl` architecture and the software-AGE-key v1 posture (PRD v1.4 is the reference).

## Decisions

**Closed:**

1. **Local substrate (2026-07-06):** `talosctl cluster create` (Docker provisioner); CAPI deferred to Milestone M-CAPI.
   Decided via zoom-out (`ZOR-ephemeral-gitops-idp-2026-07-06.md`): CAPI-locally was a means to workflow parity, container fidelity suffices for v1, Docker-only is a hard host-dependency line (which independently eliminated the Incus option, whose Talos template is CI-untested and VM-based).
2. **Devcontainer vs host-native for v1 (2026-07-06):** host-native `mise`.
   The toolchain is fully mise-managed and the only Docker requirement is `talosctl`'s provisioner reaching a single daemon socket, so the devcontainer's isolation/reproducibility upside no longer offsets its setup cost; see Phase 1 status above.

**Open:**

1. **Flux source and local iteration loop** (Phase 2, step 4) - repo visibility/auth plus the uncommitted-changes workflow.
2. **Gate 3 LB reachability mechanism** (Cilium L2 announcement policy vs a host route toward the pool; the `CiliumLoadBalancerIPPool` itself is mandatory for LB-IPAM, not part of the decision) - resolve empirically at Phase 0 gate 3.
3. **State persistence** (PRD Section 6) - only if re-hydrating data across ephemeral cycles becomes a real need; no v1 work.

## Immediate next action

Phase 0 and Phase 1 are done (green, 2026-07-06 - see status above).
Next: start Phase 2's `clusters/workload/` structure.
