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
- cert-manager and the local Root CA issuer chain (`infrastructure/cert-manager/`) -
  the `HelmRelease` (`controllers/`) and the `selfsigned` -> `root-ca` -> `local-ca`
  issuer chain (`configs/`). This is the first component using per-component Flux
  `Kustomization` CRs (`infrastructure/cert-manager.yaml`) rather than the root
  `Kustomization`: a CRD provider whose custom resources must wait for its CRDs and
  webhook needs an explicit `controllers`-then-`configs` `dependsOn` ordering, which a
  flat aggregation cannot express. Any future component with that shape follows the same
  pattern (a `<component>.yaml` of `Kustomization` CRs plus `controllers/`+`configs/`
  subdirs); components without CRD-ordering needs can stay flat like Cilium.
- Any further application/workload `HelmRelease`s and `Kustomization`s added under this
  tree (remaining Phase 3 turnkey payload: Dex, Cloudflare Tunnel).

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

Repoint back to `main` the same way once done:

```sh
kubectl patch gitrepository/flux-system -n flux-system --type=merge \
  -p '{"spec":{"ref":{"branch":"main"}}}'
```

Delete the scratch branch from the remote once you're done with it - it lives on the
same shared GitHub remote a real deployment's `GitRepository` would also point at, so
an abandoned scratch branch is a stale-but-harmless artifact on that remote, not just
local state. A scratch branch was chosen over an OCI-artifact push or offline
`flux build` diffing because it keeps the source *kind* (`GitRepository`) identical
between local and cloud - the local-iteration mechanism itself never leaks into what a
CAPI-provisioned cluster's Flux instance would need to consume. Nothing currently
detects or alerts if a local cluster is left pointed at a stale scratch branch; that's
an accepted gap for a single-developer local dev tool, not a hardened multi-user
workflow.

## Known limitations (accepted for v1, not solved by this tree)

- **No day-2 config-drift restart for agent-level Cilium flags.** The imperative
  bootstrap task (`test-talos-spike:cilium`) unconditionally restarts the Cilium
  DaemonSet after every install/upgrade because the Cilium chart does not
  checksum-annotate the agent pod template - a `helm upgrade` that changes an
  agent-level flag (e.g. `l2announcements.enabled`) updates the ConfigMap but leaves
  already-running agents on stale flags until restarted. Once Flux owns day-2 changes,
  no equivalent mechanism exists here: a legitimate Git-driven values change to such a
  flag will update the release without restarting the agents. Workaround until this is
  designed properly: `kubectl rollout restart daemonset/cilium -n kube-system` manually
  after any Git-driven change to an agent-level flag.
- **`flux-system`'s NetworkPolicies allow unrestricted egress** (inherited unmodified
  from `flux install --export`'s stock output, not introduced by this tree). The
  `git-credentials` (repo deploy key) and `sops-age` (project decryption key) secrets
  both live in this namespace with no egress scoping around the controllers that mount
  them. Accepted for v1 alongside this project's other deferred hardening item (the
  YubiKey-backed AGE key, PRD Section 3.2) rather than solved here.
