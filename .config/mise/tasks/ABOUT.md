# ⚡ Mise Autoload Tasks Directory

This directory contains standalone operational scripts that `mise` automatically discovers, parses, and loads into the workspace runtime engine.

## 📌 Architectural Conventions

1. **Automatic Registration:** Any executable file placed inside this folder is instantly registered as a runnable command (e.g., `tasks/build-assets.sh` becomes callable via `mise run build-assets`).
2. **Naming Scheme:** Keep filenames short, action-oriented, and lower-case (use hyphens, not underscores: `run-linter.sh`).
3. **No Duplication:** Do not register files in this directory manually inside your `config.toml` file via `file = ...`, or they will be listed twice in your `mise run` interactive menus.

## 📝 Frontmatter Metadata Template

`mise` parses the top header block of these scripts to build your CLI documentation. Every file in this folder **must** begin with this structure:

```bash
#!/usr/bin/env bash
#
# SCRIPT: task-name.sh
#
# DESCRIPTION:
# A concise description of what this automated workspace task achieves.
#
# Version: 2026-06-23 09:00:00 AEST
#

# --- Mise metadata
#MISE description="A clean, single-sentence summary visible in 'mise tasks' list."
#MISE hide="false"        # Change to "true" to hide utility tasks from the main menu
#MISE wait_for=["init"]   # Optional: Delay execution until dependent tasks finish
```
