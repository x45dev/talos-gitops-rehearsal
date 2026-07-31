# talos-gitops-rehearsal dev image: a stock devcontainers base plus a Docker CLI and mise.
#
# This image was previously built FROM a private shared base (ghcr.io/x45dev/devbase),
# digest-pinned for cross-host parity. That base is not public, so for publication this
# Dockerfile is self-contained: it starts from Microsoft's public devcontainers base and
# installs the two things the private base used to supply (a non-root `dev` user and mise).
#
# The Docker client is this repo's own requirement, not a general one: talosctl's docker
# provisioner and the repo's docker/compose tasks drive a Docker daemon mounted from the
# host (see compose.cluster.yaml), so the CLI has to be in the image even though the
# daemon never is.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

USER root

# The base ships a non-root `vscode` at uid/gid 1000. This repo's compose files, mounts,
# and ADR-0006 all name the user `dev`, so rename rather than add a second uid-1000 user:
# the uid/gid is what makes bind-mounted files line up with the host account.
RUN usermod -l dev vscode \
    && groupmod -n dev vscode \
    && usermod -d /home/dev -m dev \
    && if [ -f /etc/sudoers.d/vscode ]; then \
    sed -i 's/vscode/dev/g' /etc/sudoers.d/vscode \
    && mv /etc/sudoers.d/vscode /etc/sudoers.d/dev; \
    fi

# DL3008 (pin apt versions) intentionally ignored: docker-ce-cli only has to talk
# to whatever host daemon is present, and Docker's apt repo drops old point
# versions, so an exact pin would break rebuilds rather than stabilise them.
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

# Restore the non-root default user; compose overrides it to root only for the
# socket-group alignment in the cluster overlay's entry command.
USER dev

# mise, the repo's tool manager and task runner, installed per-user under
# ~/.local/bin. The activation line below only fires for INTERACTIVE shells, so
# devcontainer.json's non-interactive postCreate invokes mise by explicit path
# instead of relying on it - do not assume this line is in effect there.
# DL4006 is not applicable: SHELL is set to bash with pipefail for the piped install.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# SC2016 intentionally ignored: the activation line must land in .bashrc unexpanded,
# so `$(...)` runs when the interactive shell starts, not when this image is built.
# hadolint ignore=SC2016
RUN curl -fsSL https://mise.run | sh \
    && echo 'eval "$(~/.local/bin/mise activate bash)"' >> /home/dev/.bashrc
