---
id: PLAN-ephemeral-gitops-idp
title: Implementation plan - Ephemeral GitOps IDP (Local Edition)
status: draft
version: 0.9.0
date: 2026-07-12
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

**Status: done, green (2026-07-07).** All steps below landed; see the Decisions section for the two decisions this phase blocked on, and "Live verification evidence" below for what was actually proven, not just built.

Convert the imperative spike into the PRD's declarative in-cluster loop, and build the Kustomize layout that carries the parity contract.

1. **Done.** `clusters/workload/` is the Flux-reconciled tree: `flux-system/` (version-pinned Flux controller export plus the `GitRepository`/root `Kustomization`) and `infrastructure/cilium/` (`HelmRepository`/`HelmRelease`).
   No `clusters/management/` tree exists in v1; add it only at Milestone M-CAPI.
2. **Done.** The CAPI-consumability contract (PRD Section 5) is written down in `clusters/workload/README.md` as a checkable list of what may not leak into the tree (`talosctl`-specific node names/labels, host paths, the local Docker LB/L2 topology), plus a "Known limitations" section for two gaps accepted rather than solved this phase (see below).
3. **Done.** `test-talos-spike:flux-bootstrap` installs Flux, injects `sops-age` and `git-credentials` secrets into `flux-system`, then applies the `GitRepository` + root `Kustomization`.
   `flux2 = "2.9.0"` is pinned in the mise `[tools]` set.
4. **Decision closed** - see Decisions section: host repo confirmed private; deploy key is persistent, not per-cycle; local iteration is a scratch branch Flux's `GitRepository` tracks.
5. **Done, with one correction found live.** Cilium's first install stays imperative (`test-talos-spike:cilium`); the `HelmRelease` adopts it in place (same release name/namespace/version/values).
   The single-values-file precondition was *violated* by the first implementation pass (the imperative task duplicated every value as independent `--set` flags instead of reading `clusters/workload/infrastructure/cilium/values.yaml`) - caught by the doubt-driven-development review, not by live verification, since both copies still matched at review time by coincidence of careful duplication.
   Fixed: the imperative task now reads the same file via `helm upgrade -f`.
   A second, unrelated bug surfaced only during live verification: re-running the imperative task after Flux adoption failed with a server-side-apply field conflict against helm-controller's field manager (both trying to own the same DaemonSet/Deployment fields) - fixed with an adoption-aware guard that skips the imperative install once a `HelmRelease` already exists.
6. **Done, live-verified.** See "Live verification evidence" below.

Subject the Phase 2 module boundary (overlay layout + consumability contract) to a doubt-driven-development review before it stands - it is the load-bearing structural decision for parity.
**Done (2026-07-07).** One doubt cycle (fresh-context adversarial review via an Explore subagent) surfaced 7 findings; all were reconciled: 5 were valid and fixed (single-values-file violation above; `verify-adoption` strengthened to diff deployed values against the canonical file rather than only checking for a non-destructive history; added an `infrastructure/kustomization.yaml` aggregator so future components don't require editing the root; tightened the local-iteration README section to one unambiguous repoint mechanism), 2 were valid trade-offs documented rather than fixed (no day-2 config-drift-restart mechanism once Flux owns Cilium; `flux-system`'s inherited unrestricted-egress `NetworkPolicies` - both now in the README's "Known limitations" section, the second deferred alongside the existing YubiKey hardening milestone). No talosctl-specific leakage or CAPI-consumability violation was found.

### Live verification evidence

Ran the full chain (`mise run test-talos-spike:all`) end-to-end from a clean `teardown` three times: once pre-doubt-review (surfaced the SSA-conflict bug above), once post-fix as the idempotent-re-entry pass (also caught a transient `quay.io` registry blip during image pull - self-healed via Kubernetes' own retry, not a code defect), and once more after the doubt-driven-development fixes to confirm `verify-adoption`'s new values-diff check actually passes with the corrected single-source-of-truth wiring (2 clean helm revisions: install + adopt-upgrade, deployed values byte-identical to the canonical file).
All three gates green on every completed pass; `GitRepository`/`Kustomization` both reported `Ready`; `helm history cilium -n kube-system` never showed an `uninstalled` revision.
(Verification used the documented scratch-branch local-iteration mechanism against this repo's own feature branch, since the changes weren't yet on `main` at verification time - the same mechanism the README documents for day-2 development.)

## Phase 3 - Turnkey payload

**Status: done, live-verified (2026-07-12).** cert-manager (+ local Root CA `ClusterIssuer`), Dex (GitHub OIDC), and Cloudflare Tunnel are all built, build-validated, doubt-driven-development reviewed, and live-verified end-to-end against an ephemeral cluster.
The three external-input decisions blocking Dex and Cloudflare Tunnel (domain, tunnel credentialing, Dex connector) are closed - see Decisions below.

Build the target-cluster self-configuration as Flux `HelmRelease`/`Kustomization` objects under `clusters/workload/`:

- Cilium (already managed by Flux since the Phase 2 adoption; listed for completeness).
- cert-manager with a local Root CA `ClusterIssuer`.
- Dex (OIDC).
- Cloudflare Tunnel for ingress.

Sequence these behind Flux `dependsOn` so Cilium and cert-manager settle before Dex and the tunnel.

**Exit criteria (met, 2026-07-12):** every payload `HelmRelease`/`Kustomization` reports `Ready`; cert-manager issues a certificate from the local Root CA `ClusterIssuer`; Dex serves its OIDC discovery document; the Cloudflare Tunnel reports a live connection (or an end-to-end request through it reaches an in-cluster service); and every SOPS-encrypted secret in the payload decrypts (zero `Kustomization` decryption failures). See "Live verification evidence" below.

### cert-manager - built (2026-07-07)

Files: `clusters/workload/infrastructure/cert-manager.yaml` (two Flux `Kustomization` CRs) and `cert-manager/controllers/` (namespace + `HelmRepository` + `HelmRelease`, chart `v1.20.3`, `crds.enabled`) + `cert-manager/configs/` (`selfsigned` `ClusterIssuer` -> `root-ca` `Certificate` `isCA:true` -> `local-ca` CA `ClusterIssuer`).

**Layering decision - this is the repo's first per-component Flux `Kustomization`.** Cilium is reconciled directly by the root `flux-system` `Kustomization`; cert-manager could not follow that flat model because its `ClusterIssuer`/`Certificate` custom resources cannot be applied until the cert-manager CRDs exist and the webhook is serving - an ordering a single flat `Kustomization` cannot express. So cert-manager splits into a `controllers` layer and a `configs` layer (the standard upstream Flux pattern for a CRD-provider plus its custom resources), with `cert-manager-configs` `dependsOn` `cert-manager-controllers`. The `controllers`/`configs` subdirs are reconciled only via those CRs' `spec.path`; `infrastructure/kustomization.yaml` lists `cert-manager.yaml` (the CRs) but not the subdirs, so nothing is double-reconciled. Cilium was deliberately left untouched (no churn to its Phase 2 adoption wiring); the mixed model - one component at root, one behind sub-`Kustomization`s - is accepted, with the sub-`Kustomization` pattern documented for any future CRD-provider component.

**The webhook-ordering gate rests on helm-controller's default resource-wait, not on `wait: true` alone** (doubt-driven-development finding, 2026-07-07). `cert-manager-controllers` has `wait: true`, which waits for the `HelmRelease` to report `Ready`; the `HelmRelease` only reports `Ready` after the cert-manager Deployments (including the webhook) are rolled out *because* helm-controller's `spec.install.disableWait` defaults to `false` (poller WaitStrategy). Verified against the shipped `helmreleases` CRD, not assumed. The doubt reviewer's premise ("helm-controller doesn't `--wait` by default") is true for the raw `helm` CLI but false for Flux helm-controller; the manifest logic was correct, and the actionable residue was a comment that over-attributed the guarantee to the `Kustomization`'s `wait: true` - now corrected in `cert-manager.yaml` with an explicit warning not to set `disableWait: true` without adding a webhook `healthCheck`. **Trade-off accepted:** the gate relies on the version-agnostic default wait rather than a `spec.healthChecks` entry keyed to the (chart-version-dependent) `cert-manager-webhook` Deployment name; the residual post-rollout webhook race is absorbed by `retryInterval: 1m`.

### Dex + Cloudflare Tunnel - built (2026-07-11), live-verified (2026-07-12)

Files: `clusters/workload/infrastructure/dex/` (Dex `HelmRelease`, chart `dexidp/dex@0.24.1`, GitHub OIDC connector, TLS terminated with a `local-ca`-issued `dex-tls` certificate) and `clusters/workload/infrastructure/cloudflare-tunnel/` (`cloudflared` `Deployment`, token-mode/remote-managed tunnel). Both flat single-`Kustomization` components; `dex` `dependsOn` `cert-manager-configs`, `cloudflare-tunnel` `dependsOn` `dex`.

**doubt-driven-development review (2026-07-11):** one cycle, 16 findings - 9 valid and fixed (`wait: true` added to the root `Kustomization`, since without it the root reports Ready as soon as its own manifests apply rather than waiting for the child Kustomizations to actually reconcile; `cloudflare-tunnel` `dependsOn` corrected from an unjustified `cert-manager-configs` to `dex`; resource requests/limits added to the `cloudflared` `Deployment`; among others), 4 valid trade-offs documented in `clusters/workload/README.md`'s "Known limitations" (Cloudflare Tunnel ingress not Flux-reconciled; `noTLSVerify` on the tunnel-to-Dex hop; no GitHub org/team restriction on Dex's connector), 3 reclassified as noise after verifying the `dexidp/dex` chart's actual templates (`helm pull --untar`, not just `helm show values`) rather than assuming.

**Live verification evidence:** ran `test-talos-spike:flux-bootstrap` + `verify-adoption` + `verify-phase3` against a fresh ephemeral cluster. Surfaced and fixed two workflow bugs unrelated to the manifests themselves, both root-caused via five-whys before the fix:
one is that `mise run task1 task2 task3` silently drops every task after the first unless the tasks are separated with `:::`, which meant two earlier verification attempts silently skipped `verify-adoption`/`verify-phase3` entirely while reporting success (the reported exit code was `flux-bootstrap`'s, not the omitted tasks');
the other is that this repo's `flux-system` `Kustomization` is self-managing (it reconciles the very directory containing `gotk-sync.yaml`), so any reconcile re-applies that file's *committed* content - meaning a live `kubectl patch` or an uncommitted local edit to `spec.ref.branch` gets silently reverted on the next reconcile interval, which is what caused an earlier destructive prune (Flux fell back to `main`, which lacks the Phase 3 Kustomizations, and pruned them with `prune: true` still set).
Fixed by committing the scratch-branch override, verifying, then reverting the commit - keeping the fetched Git artifact self-consistent for the verification window instead of fighting the self-managing tree.
With that fixed, `verify-phase3` passed every exit criterion: `dex` and `cloudflare-tunnel` Kustomizations Ready; `dex-tls` `Certificate` issued from `local-ca`; Cloudflare Tunnel reporting a live/healthy connection; Dex's OIDC discovery document served end-to-end through the tunnel with a matching `issuer`; the GitHub OAuth client ID reaching the Dex pod's environment via the SOPS-encrypted secret injection; zero SOPS decryption failures across all Kustomizations.
Cluster torn down cleanly afterward (zero residue confirmed).

## Phase 4 - Lifecycle, idempotency, and metrics

1. Make the bootstrap task idempotent end-to-end: a re-run with state already reached is a no-op (PRD 3.3); every step detects its precondition and self-heals (the standing bar from the spike work).
2. Harden teardown: `talosctl cluster destroy`, verify zero orphaned Docker containers, volumes, or networks for the cluster, remove `.kube-*.config`/`.talosconfig` (PRD Success Metric 3).
3. ~~Measure spin-up time against the < 10 minute target~~ - **withdrawn 2026-07-25** (`knowledge/adr/ADR-0010.md`; feature spec `knowledge/specs/002-phase-4-lifecycle-hardening/`). The metric remains a stated target but is deliberately uninstrumented in v1, so Phase 4 no longer carries a per-stage budget. The design below is retained for the revisit trigger recorded in the ADR: measure broken into stages (cluster create, Cilium ready, Flux ready, payload `Ready`), and record a per-stage budget (first measured in Phase 0; re-measure with the full Flux-driven pipeline).
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
- **Phase 2 overlay boundary doubt-driven-development review (done, 2026-07-07):** see Phase 2 status above for the findings and fixes.
- **Update `README`/onboarding text (done, 2026-07-06):** the README no longer describes the dual-cluster CAPI architecture or asserts the YubiKey-backed v1 security posture; it reflects the single-cluster `talosctl` architecture and the software-AGE-key v1 posture (PRD v1.4 is the reference).

## Decisions

**Closed:**

1. **Local substrate (2026-07-06):** `talosctl cluster create` (Docker provisioner); CAPI deferred to Milestone M-CAPI.
   Decided via zoom-out (`ZOR-ephemeral-gitops-idp-2026-07-06.md`): CAPI-locally was a means to workflow parity, container fidelity suffices for v1, Docker-only is a hard host-dependency line (which independently eliminated the Incus option, whose Talos template is CI-untested and VM-based).
2. **Devcontainer vs host-native for v1 (2026-07-06):** host-native `mise`.
   The toolchain is fully mise-managed and the only Docker requirement is `talosctl`'s provisioner reaching a single daemon socket, so the devcontainer's isolation/reproducibility upside no longer offsets its setup cost; see Phase 1 status above.
3. **Gate 3 LB reachability mechanism (2026-07-06, resolved empirically during Phase 0, not previously reconciled here):** `CiliumL2AnnouncementPolicy`, no separate host route.
   The host shares the same L2 segment as the Docker bridge, so ARP announcement alone is sufficient; see `PRD.md` Section 6 and the Cilium ADR.
4. **Flux source and local iteration loop (2026-07-07):** this repository's GitHub remote (confirmed private via `gh repo view`), authenticated with a persistent, one-time read-only SSH deploy key (generated via `gh repo deploy-key add`, private half stored encrypted in the existing project SOPS secrets file) rather than one minted/revoked per cluster cycle.
   Local iteration on uncommitted changes: a scratch branch the `GitRepository` tracks (`kubectl patch gitrepository/flux-system ... -p '{"spec":{"ref":{"branch":"<scratch-branch>"}}}'`), chosen over an OCI-artifact push or offline `flux build` diffing because it keeps the source *kind* identical between local and cloud.
   Full rationale and the mechanism's accepted gaps: `clusters/workload/README.md`.
5. **Phase 3 external inputs (2026-07-11):** three decisions the repo could not fabricate on its own, all supplied by the user:
   - **Domain:** `idp.x45.dev`, an existing zone the user already manages on Cloudflare (zone ID `13408ba740c16ee62029e515d3c77561`, account ID `207dc3abb767103591a4f197d6a6f6fe` - both looked up live via the Cloudflare API, not guessed).
   - **Cloudflare Tunnel credentialing:** automated via a scoped API token (`Zone:DNS:Edit` + `Account:Cloudflare Tunnel:Edit`), stored as `CLOUDFLARE_API_TOKEN` in the project's SOPS secrets file, rather than a manually-created tunnel token pasted in by the user each cycle.
     A tunnel named `kind-talos-idp` already existed in the account (created 2026-07-10, `remote_config: true`) when this was picked up - the bootstrap task adopts it by name rather than creating a second one.
     `remote_config: true` means cloudflared runs in **token mode** (`cloudflared tunnel run --token ...`), which pulls its ingress rules from Cloudflare's control plane via API, not from a locally mounted config file - this is a structural property of how the tunnel object was created (dashboard/API `cfd_tunnel` resource), not a choice made here; switching to locally-managed config would mean re-provisioning the tunnel with a `credentials.json`, which was judged not worth fighting the existing resource for.
     **Accepted gap:** this makes the Cloudflare Tunnel the one piece of the turnkey payload whose live-enforced configuration is not a Flux-reconciled Kubernetes object - the desired ingress rules still live in Git (`clusters/workload/infrastructure/cloudflare-tunnel/ingress.yaml`), but an idempotent bootstrap task pushes them to Cloudflare's API rather than Flux reconciling them continuously from the cluster. Documented in `clusters/workload/README.md`'s "Known limitations" alongside the other two accepted Phase 2 gaps.
   - **Dex connector:** GitHub OAuth (`clientID`/`clientSecret` via Dex's built-in `$ENV_VAR` expansion in connector config, on by default in Dex's `expand_env` feature flag - verified against the `dexidp/dex` source, not assumed). OAuth App registered by the user at github.com/settings/developers with callback `https://idp.x45.dev/callback`; client ID/secret stored as `GITHUB_OAUTH_CLIENT_ID`/`GITHUB_OAUTH_CLIENT_SECRET` in the same SOPS file.
     **Accepted gap:** no GitHub org/team restriction (`orgs:` connector field) is configured - any GitHub account can authenticate. Acceptable for a single-user local ephemeral IDP; revisit if this ever serves more than one person.

**Open:**

1. **State persistence** (PRD Section 6) - only if re-hydrating data across ephemeral cycles becomes a real need; no v1 work.

## Immediate next action

Phase 0 through Phase 3 are done (green, Phase 3 live-verified 2026-07-12 - see status above).
Next: Phase 4, lifecycle/idempotency/metrics hardening - no work has started on it yet.
