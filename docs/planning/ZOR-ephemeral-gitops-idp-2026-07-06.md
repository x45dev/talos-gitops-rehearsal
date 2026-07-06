---
id: ZOR-ephemeral-gitops-idp-2026-07-06
title: Zoom-out report - Ephemeral GitOps IDP substrate re-frame
status: draft
version: 0.1.0
date: 2026-07-06
---

# Zoom-out report - Ephemeral GitOps IDP substrate re-frame

**Reviewed:** `PRD.md` v1.2.0 and `PLAN-ephemeral-gitops-idp-2026-07-05.md` v0.2.0, after the CAPD/Talos incompatibility finding  |  **Depth:** standard
**Decision class:** two-way door in principle, but expensive to unwind (weeks of pipeline work build on the substrate) x medium-high blast radius

## 1. Verdict

**RE-FRAME RECOMMENDED**
Descope CAPI from the local v1 loop entirely: provision the local target cluster with `talosctl cluster create` (Docker provisioner), deliver the turnkey payload with a single Flux instance in the target cluster, keep the repo layout CAPI-shaped, and re-introduce CAPI/CABPT/CACPPT only when a real cloud (CAPA) target exists.

**Confidence:** High.
The one uncertainty that would change this call: if the author later decides that operating the CAPI machinery locally is itself a terminal goal (rehearsal value), the Incus path re-enters despite its immaturity - but the interview explicitly ruled that out for v1, and the Docker-only constraint independently eliminates Incus anyway.

## 2. What was on the table

- **Stated problem:** a deterministic, sub-10-minute, ephemeral local Talos cluster whose GitOps workflow carries unchanged to a future AWS/CAPA pipeline, with secrets kept off Git via SOPS/AGE.
- **Core premise (the load-bearing if/then):** if the local loop uses CAPI with a local infrastructure provider, then the same GitOps provisioning wiring transfers to cloud CAPI later.
  The original form of this premise ("CAPD is that local provider") was falsified by live probe on 2026-07-06: CAPD's `DockerMachine` controller unconditionally execs bootstrap data as a kubeadm join script and cannot consume Talos machine configs.
- **Expensive decisions at stake:** (1) the dual-cluster, dual-Flux architecture; (2) Talos in the local loop at all; (3) the replacement substrate (the PRD's Option A `talosctl` vs Option B Incus); (4) the Cilium 1.19.5 + Kubernetes 1.35 + Talos 1.13 version pin.
- **Load-bearing assumptions tested:**
  1. "Workflow parity requires the local target to be CAPI-managed" - fragility High, impact Severe.
     Found to be an overreach: PRD Section 5 already concedes the infra base is provider-specific and unmeasured, so the only thing a local CAPI target rehearses is a throwaway base plus the outer Flux-to-CAPI loop.
  2. "Incus has documented Talos support" (plan doc) - fragility High, impact Severe if relied on.
     Verified directly: the CAPN Talos template is CI-untested ("could be broken", their words), runs Talos as **VMs** from nocloud qcow2 images (the plan's "containers" claim is factually wrong), is version-skewed (tested Talos 1.12.2 vs the project's 1.13 pin), and ships a haproxy SPOF.
  3. "Cilium works on Talos-in-Docker" - confirmed feasible upstream (siderolabs/talos discussion #9849) with a documented workaround (`--skip-k8s-node-readiness-check`, then manual kubeconfig fetch) plus the same cni/proxy patches already authored for the CAPD template.

## 3. Evidence matrix

Four framings were scored by disconfirmation (ACH), not two:
H1 = PRD Option B (keep CAPI, swap CAPD for `cluster-api-provider-incus`); H2 = PRD Option A extended into the recommended re-frame (`talosctl` + single-loop Flux, CAPI deferred); H3 = keep CAPD, drop Talos locally (kubeadm local, Talos cloud-only); H4 = incumbent as written (CAPD+Talos), retained as a control.

| Evidence | H1 Incus | H2 talosctl (re-frame) | H3 CAPD+kubeadm | H4 CAPD+Talos |
| --- | --- | --- | --- | --- |
| CAPD cannot exec Talos bootstrap data (proven live, controller logs) | consistent | consistent | consistent | **inconsistent - falsified** |
| Incus Talos template CI-untested, VM-based, version-skewed (verified at capn.linuxcontainers.org) | **inconsistent** | neutral | neutral | neutral |
| PRD parity contract = workflow + app overlay only; infra base conceded provider-specific | consistent | consistent | consistent | consistent |
| PRD Section 1 goal: "production-identical Talos locally" (interview: container fidelity suffices) | consistent | consistent | **inconsistent** | consistent |
| Docker-only host dependency as a hard line (interview answer, new constraint) | **inconsistent - eliminated** | consistent | consistent | consistent |
| Sub-10-minute spin-up, deterministic Docker teardown metrics | strained (VM images, second daemon) | consistent (fastest known Talos path) | consistent | n/a |
| Cilium-on-Talos-in-Docker feasibility (upstream-confirmed, #9849) | neutral | consistent | neutral | untestable |
| PRD 3.1 pivot clause: "if parity descoped, revisit single-loop or non-CAPI local path" | neutral | consistent (this is that clause firing) | neutral | neutral |

H2 is the only framing with zero inconsistencies.
H1 carries two, one of them a hard constraint violation.
H3 dies on Talos fidelity; H4 is dead on arrival.

*Most diagnostic evidence:* the interview's "Docker-only is a hard line" answer - it eliminates H1 outright regardless of every other consideration, and it was not derivable from any written artifact.
Second most: the verified immaturity of the Incus Talos template, which had been recorded in the plan as stronger evidence ("documented Talos support") than it actually is.

## 4. Interview

- **Asked:** (1) Is local CAPI a terminal goal (rehearsal) or a means to workflow parity?
  (2) How literally does "production-identical Talos locally" bind (container vs VM vs negotiable)?
  (3) Is an Incus/LXD daemon an acceptable v1 host dependency?
- **Answered:** (1) Means to parity.
  (2) Container fidelity is fine.
  (3) Docker-only is a hard line.
- **Effect on verdict:** all three moved it, convergently.
  Answers 1 and 3 are new evidence (constraints not written anywhere); answer 2 confirms an assumption the incumbent already made.
  Together they eliminate H1 and H3 and select H2 over a bare "Option A" reading - since CAPI is a means, deferring it is a descope, not a loss.

## 5b. The re-frame

- **New core premise (1 sentence):** the parity worth buying locally is the Flux workflow plus the app/workload overlay, so the local v1 loop is `talosctl cluster create` (Docker provisioner, cni none, proxy disabled) plus a single Flux instance in the target cluster reconciling the turnkey payload, with the repo layout kept CAPI-shaped for the day a real CAPA target exists.
- **Why it wins (from the matrix):** it is the only framing with no disconfirming evidence; it satisfies the Docker-only hard constraint, the sub-10-minute metric, and the Talos-locally goal simultaneously; and the parity it forfeits (the outer Flux-to-CAPI loop) was only ever going to be rehearsed against a throwaway provider-specific base that no longer exists.
- **Survived its own critique:** the strongest case against is that deferring CAPI risks the "CAPI-shaped" repo layout rotting into a fiction, and that the dual-Flux muscle memory never gets built.
  This holds anyway because (a) the PRD itself pre-authorized this pivot (Section 3.1), (b) rehearsing CAPI against a substrate Sidero does not support teaches wrong lessons, not fewer lessons, and (c) the overlay contract can be kept honest with a documented "what CAPI will consume" note instead of a live local consumer.
  A second-order cost to price in: the management `kind` cluster loses its v1 job (no CAPI to host; SOPS identity injection retargets to the workload cluster directly), so Phase 1's devcontainer/DinD analysis simplifies rather than restarts.
- **Migration path (high level):**
  1. Stop: no further work on `capd-talos-template.yaml`, the CAPD socket topology, or the Incus evaluation.
  2. Keep: the Talos cni/proxy patches (they port near-verbatim to `talosctl --config-patch`), the Cilium/validate gate tasks, the idempotency patterns, and the mise env fixes.
  3. Change first: rewrite `test-capd-spike:setup`/`provision` around `talosctl cluster create` with `--skip-k8s-node-readiness-check`; then run gates 1-3 unchanged.
  4. Then: revise PRD (v1.3) and plan (v0.3) to the single-loop v1 architecture with CAPI as a labeled future milestone, and extract the CAPD-incompatibility ADR.

## 5a. Residual risks and pivot indicators

- **Residual risks (3):**
  1. **Cilium 1.19.x pin:** cilium/cilium#46010 reports Cilium 1.19.x with `kubeProxyReplacement=true` on Talos 1.13 killing host networking during BPF/veth init (single report, closed, but exactly on this project's pin).
     Mitigation: if gate 1 fails with host-networking symptoms, probe Cilium 1.18.x before debugging anything else.
  2. **Fidelity gap:** Talos-in-Docker shares the host kernel, so eBPF behavior validated locally is the host kernel's, not production Talos's.
     Accepted by the author for v1; recheck at the first cloud deployment.
  3. **Deferred-parity rot:** with no live CAPI consumer, the overlay boundary can drift.
     Keep the "what CAPI will consume" contract written down when Phase 2 builds the overlay.
- **Leading indicators / signposts:** a real CAPA/cloud target getting scheduled (re-introduce CAPI then, with a management cluster whose substrate question is then trivial - it manages cloud, not Docker); any turnkey payload component proving impossible on the Docker provisioner (none identified today); the talosctl Docker provisioner losing upstream support (no sign of this; it is Sidero's primary quickstart path).

## 6. Executive summary

The project's premise was that a local CAPI+CAPD+Talos loop would rehearse the future cloud pipeline, but a live probe proved CAPD architecturally cannot bootstrap Talos, and the only CAPI-preserving substitute (Incus) is CI-untested, VM-based, and violates the author's Docker-only constraint.
The interview established that CAPI locally was a means to workflow parity, not a goal, and the PRD's own pivot clause anticipated exactly this case.
The recommended re-frame keeps everything the parity contract actually measures - the Flux workflow and the app overlay - by provisioning the local Talos cluster with `talosctl cluster create` and deferring all CAPI machinery until a real cloud target exists.

---
*Generated by the zoom-out skill. For independent validation, hand this file to a different model and ask whether it agrees with the comparative logic in the evidence matrix (section 3), not merely the verdict.*
