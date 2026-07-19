#!/usr/bin/env bash
# Idempotent launcher for this project's devcontainer (see ADR-0006).
#
# Pins an explicit Compose project name derived from the repo directory name,
# not the default (the containing folder, always literally ".devcontainer"),
# so containers for different projects on the same host never collide.
# Safe to re-run: `docker compose up -d --build` only recreates the container
# when the image or compose config actually changed.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_name="$(basename "$repo_root")"
container_name="${project_name}-dev-1"

cd "$repo_root/.devcontainer"
docker compose -p "$project_name" up -d --build

echo "Container: $container_name (compose project: $project_name)"
echo "Attach:    docker exec -it $container_name zellij attach --create claude-<session-name>"
