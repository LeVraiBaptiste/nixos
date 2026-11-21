# NixOS Configuration Guide

## System Commands

Always rebuild through `scripts/rebuild.sh` (fish alias `rebuild`): it decrypts the personal values (`private/vars.yaml`) and passes them as `--override-input private`. A plain `nixos-rebuild` uses the placeholders in `private/example/` and fails on an assertion.

- `rebuild` - Rebuild and apply the current host (desktop or laptop)
- `rebuild server` / `rebuild remote` - Deploy over SSH (uses the `server`/`remote` ssh aliases)
- `rebuild-all` - Current host, then server, then remote

## Code Style Guidelines

- **Nix Formatting**: Use 2-space indentation in .nix files
- **Imports**: Group imports at the top of files by category (nixos, home)
- **Naming Conventions**: Use kebab-case for module names and camelCase for variables
- **Comments**: Comment complex configurations and provide explanations for non-obvious settings
- **Error Handling**: Use `lib.mkDefault` to establish fallback values for settings

## Project Structure

- `flake.nix` - Flake entry point with `desktop`, `laptop`, `server`, and `remote` configurations (nixpkgs unstable, home-manager, disko, sops-nix, zen-browser, claude-foreman)
- `hosts/` - Host-specific configurations (each host is a directory with `default.nix` + `hardware-configuration.nix`)
    - `desktop/` - Desktop: nvidia, steam, dictation, obs, davinci-resolve, all modules
    - `laptop/` - Laptop: lighter config (no nvidia, steam, or dictation)
    - `server/` - Home server (Dell T330): docker-compose services (Home Assistant, Jellyfin, WireGuard)
    - `remote/` - Public-facing gateway: WireGuard hub, native Caddy ingress (`modules/nixos/edge.nix`), uses disko
- `modules/` - Modular components:
    - `nixos/` - System-level NixOS modules (boot, network, bluetooth, gnome, audio, printing, nvidia, docker, ssh, steam, brave, dictation, obs, ollama, etc.)
    - `home/` - Home-manager modules (git, fish, dev tools, claude-code, ghostty, kitty, neovim, tmux, lazygit, messaging, vpn, locale)
- `config/` - Dotfiles and service configs
    - `nvim/` - Neovim configuration (NvChad-based)
    - `ghostty.conf`, `kitty.conf`, `lazygit.yml`, `tmux.conf` - Terminal/tool configs
    - `server/` - Server docker-compose and Caddyfile
- `scripts/` - Shell/Python scripts (dictation, whisper speech-to-text, HA config backup, IPMI fan control)
- `models/` - Whisper model files (ggml-base, ggml-medium, ggml-large-v3-turbo)
- `overlays/` - Nix overlays (claude-code)
- `docs/` - Documentation (architecture, wireguard setup, secrets)
- `vars.nix` - Shared non-secret values (LAN/WireGuard IPs, ports, public keys), committed
- `private/` - Personal values read at evaluation (domain, public IP, git identities, emails): `vars.yaml` sops-encrypted, `example/vars.json` placeholders (default flake input)
- `secrets/` - sops-encrypted secrets (`sops secrets/server.yaml` to edit, recipients in `.sops.yaml`, see `docs/secrets.md`)

## Environment

- Default shell: Fish with custom aliases and plugins
- System packages managed via environment.systemPackages
- Home configuration managed with home-manager (desktop and laptop only)
