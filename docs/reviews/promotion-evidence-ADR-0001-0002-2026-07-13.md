# Promotion evidence: ADR-0001 and ADR-0002 (active -> canonical)

Uninducted working material - the in-repo formal-review record RFC-002 section 4 /
PRD FR5.2 require for an `active` -> `canonical` promotion. First exercise of the RKA
promotion gate on any repository.

## Proposer and reviewer

- **Proposer (author side):** AI agent (Claude). Furnishes the evidence below; may
  advocate; **does not execute the promotion** (RFC-000 P4, RFC-002 section 4).
- **Non-author reviewer (the gate):** the human. These ADRs were inducted by a prior
  discovery agent and their promotion is proposed by an agent, so the human is the
  qualifying non-author reviewer who adjudicates this evidence and records the decision.

## Review scope

- **Documents:** `knowledge/adr/ADR-0001.md`, `knowledge/adr/ADR-0002.md` (both moved
  `draft` -> `active` by informal verification in the same change that added this file).
- **What was examined:** every mechanically-checkable claim in each ADR, against the
  actual committed repository state, plus each ADR's internal consistency and its
  own documented live-probe evidence. Runtime behaviour was **not** re-executed (no
  Talos/Docker/Helm environment in this review context); see "What might still be wrong".

## Verification evidence

### ADR-0001 (drop CAPD; provision Talos directly with `talosctl cluster create`)

| ADR claim | Checkable artefact | Result |
| --- | --- | --- |
| The CNI/kube-proxy-disable patch survives as `.config/talos/cni-none.patch.yaml` | `.config/talos/cni-none.patch.yaml` | **Present** - confirmed |
| `.config/capi/capd-talos-template.yaml` and `.config/kind/` are deleted as of Phase 0 | `.config/capi`, `.config/kind` | **Absent** - confirmed (matches "deleted") |
| Repository layout stays CAPI-shaped (`clusters/management/`, `clusters/workload/`), management unpopulated in v1 | `clusters/` tree | `clusters/workload/{flux-system,infrastructure}` present; `clusters/management/` **not materialised** - consistent with "unpopulated" (git does not track empty dirs). Minor phrasing gap, see below. |

The decision's root-cause narrative (CAPD's `DockerMachine` unconditionally execs the
bootstrap secret as a kubeadm join script; Talos emits machine-config YAML never meant
to be exec'd; the `invalid character 'v'` error is CAPD JSON-decoding Talos's
`version:` header) is internally coherent and matches the cited controller-log evidence.
The decision was reached via a recorded ACH zoom-out (`ZOR-...-2026-07-06.md`) scoring
four framings by disconfirmation - the reasoning trail is preserved.

### ADR-0002 (pin Cilium 1.18.11, not 1.19.x)

| ADR claim | Checkable artefact | Result |
| --- | --- | --- |
| The spike `cilium` task installs 1.18.11, not 1.19.5 | `.config/mise/tasks/test-talos-spike.toml:95` | `--version 1.18.11` - **confirmed** |
| The task rolls the DaemonSet after install (chart lacks a config-checksum) | `.config/mise/tasks/test-talos-spike.toml:107` | `kubectl rollout restart daemonset/cilium` - **confirmed** |
| Phase 2's Flux `HelmRelease` must pin the same 1.18.11 | `clusters/workload/infrastructure/cilium/helmrelease.yaml:21` | `version: "1.18.11"` - **confirmed**; the forward-looking consequence is already satisfied consistently |

The methodological finding - that a `helm uninstall`/`upgrade` swap on the *same* nodes
inherits stale eBPF/tc/iptables datapath state and yields a false negative, so any
re-test must use freshly provisioned nodes - is a durable, non-obvious constraint,
independently reproduced (a second data point on cilium/cilium#46010 with a distinct
signature: host-network DNS resolution failure, not full host-networking loss).

## What might still be wrong (honest account)

1. **No live re-execution.** This review verified the *committed artefacts* the ADRs
   describe, not the *runtime behaviour*. The talosctl/Cilium probe results rest on the
   ADRs' own documented 2026-07-06 live runs, not a fresh run in this context. For an
   architectural decision this is appropriate (the artefacts encode the decision), but
   the canonical claim "1.19.x breaks host DNS on this stack" is trusted from a single
   documented reproduction, not re-reproduced here.
2. **ADR-0001 minor phrasing.** It states the layout "stays CAPI-shaped
   (`clusters/management/`, `clusters/workload/`)"; `clusters/management/` is not
   materialised in the tree. This is consistent with "unused and unpopulated in v1" but
   the parenthetical reads as if the directory exists. Non-blocking; worth a wording
   tweak on next edit, not a reason to withhold promotion.
3. **Forward-looking consequences.** Some ADR-0001 consequences (the future CAPA/CAPI
   re-introduction, the base/overlay CAPI-consumability contract) describe intent for
   milestones not yet built; they are correctly framed as future work, not current
   fact.

## Proposed decision (for the human to record)

Both ADRs are substantially correct, internally consistent, and corroborated by the
committed repository state; ADR-0002 additionally has every checkable claim confirmed
including a forward consequence already implemented. I **propose promotion of both to
`canonical`**, with the two caveats above recorded.

To record an affirmative decision, the human sets `status: canonical` on each ADR and
records the decision (this file plus the promoting commit's message are the retrievable
record). If the human prefers, ADR-0001 can be held at `active` pending the phrasing
tweak while ADR-0002 is promoted; ADR-0002 is the cleaner of the two.

**Until that recorded human decision, both remain `active`.** The agent does not set
`canonical`.
