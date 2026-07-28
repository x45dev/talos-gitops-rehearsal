# kind-talos-gitops dev image: the shared devbase base plus a Docker CLI.
#
# The devbase image (ghcr.io/x45dev/devbase) deliberately ships no Docker
# client - it is a general dev base. This repo's workload needs one: talosctl's
# docker provisioner and the repo's docker/compose tasks drive a Docker daemon
# (mounted from the host, see compose.yaml). Rather than bloat the shared base
# for one consumer, add the CLI in a thin project image that FROMs it - the
# extension pattern the base's own example devcontainer documents.
#
# The base is digest-pinned (not the floating :dev tag) so laptop and VPS build
# on the byte-identical base image (cross-host parity). Re-pin deliberately on
# each intentional base rebuild.
FROM ghcr.io/x45dev/devbase@sha256:a9689b11c563c09f61670230c9e70180a2122ffee38871502f36d13942f1f382

USER root
# DL3008 (pin apt versions) intentionally ignored: docker-ce-cli only has to talk
# to whatever host daemon is present, and Docker's apt repo drops old point
# versions, so an exact pin would break rebuilds rather than stabilise them. The
# reproducibility that matters (the base) is handled by the digest pin above.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# Restore the base image's non-root default user; compose overrides it to root
# only for the socket-group alignment in the entry command.
USER dev
