# NixOS Configuration Guide

## System Commands

- `sudo nixos-rebuild switch --flake /etc/nixos#desktop` - Rebuild and apply desktop configuration
- `sudo nixos-rebuild switch --flake /etc/nixos#laptop` - Rebuild and apply laptop configuration
- `cd /etc/nixos && code .` - Open NixOS config in VS Code

## Code Style Guidelines

- **Nix Formatting**: Use 2-space indentation in .nix files
- **Imports**: Group imports at the top of files by category (system, home, dev)
- **Naming Conventions**: Use kebab-case for module names and camelCase for variables
- **Comments**: Comment complex configurations and provide explanations for non-obvious settings
- **Error Handling**: Use `lib.mkDefault` to establish fallback values for settings

## Project Structure

- `flake.nix` - Flake entry point with `desktop` and `laptop` configurations (nixos-unstable, home-manager)
- `hosts/` - Host-specific configurations
    - `desktop.nix` - Desktop: nvidia, steam, dictation, all modules
    - `laptop.nix` - Laptop: lighter config (no nvidia, steam, or dictation)
    - `hardware-configuration.nix` - Hardware config
- `modules/` - Modular components:
    - `system/` - Core system config (boot, network, bluetooth, GNOME extensions, audio, printing, user)
        - `nvidia.nix` - NVIDIA drivers (desktop-only, imported by host)
        - `virt/docker.nix` - Docker virtualization (imported by hosts)
    - `home/` - Home-manager config (locals, Fish shell, dconf, packages)
    - `dev/` - Dev tools (languages, editors, claude-code), terminal (kitty), Mattermost, VPN
    - `brave.nix`, `steam.nix`, `dictation.nix` - Standalone app modules
- `scripts/` - Shell/Python scripts for dictation and whisper speech-to-text
- `models/` - Whisper model files (ggml-base, ggml-medium)

## Environment

- Default shell: Fish with custom aliases and plugins
- System packages managed via environment.systemPackages
- Home configuration managed with home-manager
