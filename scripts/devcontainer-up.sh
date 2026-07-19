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

# `postCreateCommand` in devcontainer.json is a devcontainer-spec hook, only
# ever run by the `devcontainer` CLI / VS Code - `docker compose up` alone
# never executes it, so the agent-config symlinks and lefthook install would
# otherwise silently never happen. Extract and run it directly instead of
# depending on tooling this workflow doesn't use. Re-running is harmless: the
# symlinks are `ln -sf`, `mise trust`/`install` and `lefthook install` are
# idempotent. Run with cwd = workspaceFolder, matching what the devcontainer
# CLI does natively - lefthook (and any future step relying on being inside
# the repo) needs that, not $HOME.
devcontainer_json="$repo_root/.devcontainer/devcontainer.json"
post_create_cmd="$(grep -v '^[[:space:]]*//' "$devcontainer_json" | jq -r '.postCreateCommand // empty')"
workspace_folder="$(grep -v '^[[:space:]]*//' "$devcontainer_json" | jq -r '.workspaceFolder // empty')"
if [ -n "$post_create_cmd" ]; then
    docker exec -w "${workspace_folder:-/}" "$container_name" bash -c "$post_create_cmd"
fi

echo "Container: $container_name (compose project: $project_name)"
echo "Attach:    docker exec -it $container_name zellij attach --create claude-<session-name>"
