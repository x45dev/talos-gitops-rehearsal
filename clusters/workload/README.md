# `clusters/workload/` - CAPI-consumability contract

This directory is the Flux-reconciled turnkey payload: the GitOps workflow and
application/workload overlay that PRD Section 5 says must carry over, unchanged, to a
future CAPI-provisioned cloud cluster (Milestone M-CAPI in
`docs/planning/PLAN-ephemeral-gitops-idp-2026-07-05.md`).
That parity only holds if nothing in this tree assumes *how* the cluster it runs on was
provisioned.

## The contract

Nothing under this directory may reference:

- **`talosctl`-specific node names or labels.** No `nodeSelector`, `nodeName`,
  `nodeAffinity`, or `topologySpreadConstraint` keyed to a node name or label that only
  `talosctl cluster create` assigns (e.g. its sequential `<cluster>-controlplane-1`
  naming). A CAPI-provisioned cluster names and labels nodes differently.
- **Local filesystem paths.** No `hostPath` volumes, no paths under the developer's
  home directory or this repository's working copy. Everything a `HelmRelease` or
  `Kustomization` needs must come from the Helm chart, a `ConfigMap`/`Secret`, or the
  Git source itself - never the host filesystem.
- **The Docker provisioner's network topology.** The `CiliumLoadBalancerIPPool` and
  `CiliumL2AnnouncementPolicy` in `infrastructure/cilium/values.yaml`'s companions are
  provisioned imperatively by the bootstrap task, outside this tree, precisely because
  their IP ranges are specific to the local Docker bridge subnet and have no cloud
  equivalent - see "What is environment-specific" below.

## What this directory *will* provide, regardless of environment

- The Flux `GitRepository`/`Kustomization` source-and-sync objects (`flux-system/`).
- The Cilium `HelmRelease` and its values (`infrastructure/cilium/`) - chart, version,
  and Talos-specific values (KubePrism endpoint, cgroup/capability settings) all carry
  over, because Talos itself (not `talosctl`) is the constant across local and cloud.
- Any future application/workload `HelmRelease`s and `Kustomization`s added under this
  tree (Phase 3 turnkey payload).

## What is environment-specific, and deliberately lives outside this tree

- **Cluster provisioning itself.** Locally: `talosctl cluster create` (imperative,
  idempotent). On cloud: declarative CAPI manifests (`AWSCluster`/`AWSMachineTemplate`,
  `TalosControlPlane`/`TalosConfigTemplate`) reconciled by a separate management
  cluster. There are no CAPI manifests in this repository in v1.
- **The LoadBalancer IP pool and L2 announcement policy** (gate 3's mechanism) - scoped
  to the local Docker bridge subnet, applied imperatively by
  `test-talos-spike:cilium`, not part of this tree. A cloud target uses a cloud
  load-balancer integration instead.
- **The initial imperative Cilium install** (`test-talos-spike:cilium`) - Flux cannot
  deliver its own CNI prerequisite (its controllers are ordinary pod-network
  `Deployment`s), so bootstrapping stays imperative; the `HelmRelease` in this tree
  then adopts that release in place (same name/namespace/version/values) so day-2
  changes flow through Git afterwards.

## Local iteration

Flux's `GitRepository` (`flux-system/gotk-sync.yaml`) tracks `main` by default. To test
uncommitted manifest changes against an ephemeral local cluster, push them to a scratch
branch and repoint the source:

```sh
kubectl patch gitrepository/flux-system -n flux-system --type=merge \
  -p '{"spec":{"ref":{"branch":"<scratch-branch>"}}}'
```

Repoint back to `main` (re-apply `gotk-sync.yaml`, or patch again) once done. A scratch
branch was chosen over an OCI-artifact push or offline `flux build` diffing because it
keeps the source *kind* (`GitRepository`) identical between local and cloud - the
local-iteration mechanism itself never leaks into what a CAPI-provisioned cluster's
Flux instance would need to consume.
