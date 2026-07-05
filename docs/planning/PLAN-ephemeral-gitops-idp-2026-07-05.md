---
id: PLAN-ephemeral-gitops-idp
title: Implementation plan - Ephemeral GitOps IDP (Local Edition)
status: draft
version: 0.1.0
date: 2026-07-05
---

# Implementation plan - Ephemeral GitOps IDP

This plan sequences the work from the current state to the PRD's success metrics.
It is grounded in a live probe of the running `capi-test` management cluster on 2026-07-05, not on assumptions.
Read it alongside `PRD.md` (the spec) and `ZOR-ephemeral-gitops-idp-2026-07-05.md` (the validated frame).

## Current state (evidence-based)

The `kind` management cluster exists and `clusterctl init` has installed all controllers (capi, capd, cabpt, cacppt, cert-manager), all Running.
The bespoke CAPD+Talos template (`.config/capi/capd-talos-template.yaml`) is admission-valid and accepted by the controllers.
Applying it was probed live, which surfaced the real blocker and cleared two suspected ones:

- **BLOCKER (found): CAPD cannot reach the Docker daemon.**
  The CAPD controller fails with `Cannot connect to the Docker daemon at unix:///var/run/docker.sock`, so the `DockerCluster` never reaches Ready and no `Machine` is ever created.
  Root cause: `test-capd-spike:setup` runs a plain `kind create cluster`, which does not mount the host Docker socket into the management cluster.
  CAPD provisions target nodes as sibling containers on the host daemon and therefore requires that socket.
- **CLEARED: the provider version skew is not fatal.**
  Despite CAPD core being `v1.13.3` and the Talos providers being older (`control-plane v0.5.13` / `bootstrap v0.6.12`, `v1alpha3` CRDs), CACPPT reconciles the `TalosControlPlane` correctly and simply waits on `cluster infra not ready`.
  No contract rejection occurred.
- **CLEARED: the template shape is correct.**
  All seven objects (Cluster, DockerCluster, two DockerMachineTemplates, TalosControlPlane, TalosConfigTemplate, MachineDeployment) apply and are picked up by their controllers.

Nothing beyond the spike exists yet: there are no Flux manifests, no `clusters/management` or `clusters/workload` tree, no turnkey payload, and no `.devcontainer/`.

## Phase 0 - Get the spike to green (unblocks everything)

The entire PRD rests on "Cilium works inside CAPD Talos containers." Until the three engineering gates pass, no pipeline should be built on top. This is the cheapest and riskiest work, so it goes first.

1. **Fix the Docker socket access.**
   Add a `kind` cluster config that bind-mounts the host Docker socket into the management node:

   ```yaml
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   nodes:
     - role: control-plane
       extraMounts:
         - hostPath: /var/run/docker.sock
           containerPath: /var/run/docker.sock
   ```

   Wire `test-capd-spike:setup` to `kind create cluster --name capi-test --config <that file>`.
   Note the devcontainer interaction: inside the devcontainer the socket must be the daemon that also hosts the `kind` node (see Phase 1); confirm both sit on the same daemon.
2. **Re-run `mise run test-capd-spike:provision`** and confirm the `DockerCluster` reaches Ready and Machines are created and become Ready.
3. **Run `test-capd-spike:cilium` then `test-capd-spike:validate`** and confirm the three gates:
   Cilium DaemonSet healthy (no BPF mount `CrashLoopBackOff`), cross-node pod-to-pod curl, and a `LoadBalancer` IP allocated and reachable from the host.
   Cilium's L4 LB needs an IP pool; if `ipam.mode=kubernetes` does not yield an external IP inside the CAPD network, add a `CiliumLoadBalancerIPPool` scoped to the Docker subnet.
4. **Exit criteria:** all three gates green from a clean `test-capd-spike:setup` through `:validate`, reproducibly.

## Phase 1 - Resolve the devcontainer gap (decision required)

`test-capd-spike:setup` and `setup.toml` reference `.devcontainer/scripts/bootstrap.sh`, which does not exist (known deferred gap).
This is real infrastructure work (Dockerfile, compose, DinD wiring, bootstrap.sh) and interacts directly with the Phase 0 socket fix.

- **Decision:** does v1 run inside a devcontainer (isolation, reproducibility, matches the referenced setup) or host-native `mise` (simpler, fewer DinD layers)?
- If devcontainer: it needs its own short spec, because the DinD-plus-CAPD-socket topology is the subtle part and should be designed, not bolted on.
- Recommendation: decide this immediately after Phase 0, because the working socket topology from the green spike is exactly the input that spec needs.

## Phase 2 - GitOps repository structure

Convert the imperative `mise` spike into the declarative two-loop design the PRD describes, and build the Kustomize layout that carries the parity (PRD Section 5).

1. Create `clusters/management/` (Flux reconciles CAPI resources: the CAPD+Talos template moves here from `.config/capi/`) and `clusters/workload/` (Flux reconciles the turnkey payload).
2. Separate the provider-specific infrastructure base (Cluster, infra kinds, Talos `configPatches`) from the provider-agnostic workload overlay, so the future CAPD to CAPA swap touches only the base (PRD Open Question 3).
3. Install Flux into the management cluster; add the second Flux instance into the target cluster as part of the turnkey payload.
4. **Exit criteria:** the same result as the green Phase 0 spike, but driven entirely by Flux reconciliation from Git rather than `mise run` steps.

## Phase 3 - Turnkey payload

Build the target-cluster self-configuration as Flux `HelmRelease`/`Kustomization` objects under `clusters/workload/`:

- Cilium (already validated in Phase 0; move its Helm values into a `HelmRelease`).
- cert-manager with a local Root CA `ClusterIssuer`.
- Dex (OIDC).
- Cloudflare Tunnel for ingress.

Sequence these behind Flux `dependsOn` so Cilium and cert-manager settle before Dex and the tunnel.

## Phase 4 - Lifecycle, idempotency, and metrics

1. Make the bootstrap task idempotent end-to-end: a re-run with state already reached is a no-op (PRD 3.3).
2. Harden teardown: delete the `kind` cluster, prune the CAPD containers and networks for the target cluster, and remove `.kube-*.config` / `.talosconfig`.
   Verify zero orphaned Docker containers or networks afterward (PRD Success Metric 3).
3. Measure spin-up time against the < 10 minute target and record it.

## Phase 5 - Security hardening (deferred milestone)

Move SOPS/AGE decryption to a hardware-bound key via `age-plugin-yubikey`, so the private key never exists in plaintext on disk and decryption blocks on a physical touch (PRD 3.2).
This is explicitly not a v1 blocker; the software AGE-key posture ships first.

## Cross-cutting

- After the spike is green (Phase 0) and after the pipeline works (Phase 2), extract durable knowledge into ADRs: the docker-socket requirement, the provider-version-compatibility finding, and the CAPD-to-CAPA parity boundary.
- Subject the Phase 2 module boundary (base vs overlay split) to a doubt-driven-development review before it stands, since it is the load-bearing structural decision for parity.

## Decisions needed (do not block Phase 0)

1. **Devcontainer vs host-native for v1** (Phase 1) - recommendation: decide right after Phase 0 using the working socket topology as input.
2. **Imperative-first then convert, vs GitOps-from-the-start** - recommendation: keep the imperative `mise` spike as the Phase 0 de-risking harness, then convert to Flux in Phase 2 rather than building both at once.
3. **Cilium LB IP strategy inside the CAPD Docker network** (`ipam.mode=kubernetes` vs an explicit `CiliumLoadBalancerIPPool`) - resolve empirically during Phase 0 gate 3.

## Immediate next action

Implement the Phase 0 step 1 Docker-socket fix in `test-capd-spike:setup` and re-run the spike through `:validate`.
That single change is what stands between the current "controllers up, nothing provisions" state and the first real evidence that the architecture works.
