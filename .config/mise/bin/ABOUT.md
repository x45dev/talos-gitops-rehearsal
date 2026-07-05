# 🛠️ Private Project Executables (Mise Bin)

This directory acts as an isolated sandbox for specialized, stateful helper scripts. Files here are **ignored by automatic directory scanning**, allowing you to explicitly route and configure them through the project Mise TOML file.

## 📌 Architectural Conventions

1. **Explicit Mapping Only:** Scripts here *only* execute when wired up inside `config.toml` or `mise.toml` using the `file =` configuration property.
2. **Interactive TUI Support:** Use this directory for lifecycle tasks requiring real-time terminal manipulation, custom password inputs, or loops (e.g., encryption utilities, interactive deployment pickers).
3. **No Extensions:** Drop the `.sh` file extension entirely from the filename (e.g., use `sops-manage-secrets`, not `sops-manage-secrets.sh`) to mimic native standalone binaries.

## 📝 Configuration Wiring Example

Because `mise` skips scanning this directory, you must explicitly declare properties like interactive raw streams (`raw = true`) or dependency graphs (`depends_on`) inside the **`config.toml`** configuration file:

```toml
[tasks.secrets]
description = "SOPS/AGE: Interactive helper to manage repo environment variables."
file = "./.config/mise/bin/sops-manage-secrets"
depends_on = ["sops-check-key"]
raw = true # 🌟 Required: Preserves standard input channels for interactive prompts
```
