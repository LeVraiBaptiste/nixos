# NixOS Configuration Guide

## System Commands
- `sudo nixos-rebuild switch -I nixos-config=/etc/nixos/hosts/desktop.nix` - Rebuild and apply system configuration
- `cd /etc/nixos && code .` - Open NixOS config in VS Code

## Code Style Guidelines
- **Nix Formatting**: Use 2-space indentation in .nix files
- **Imports**: Group imports at the top of files by category (system, home, dev)
- **File Structure**: 
  - `hosts/` - System-specific configurations
  - `modules/` - Modular components (system, home, dev)
- **Naming Conventions**: Use kebab-case for module names and camelCase for variables
- **Comments**: Comment complex configurations and provide explanations for non-obvious settings
- **Error Handling**: Use `lib.mkDefault` to establish fallback values for settings

## Git Configuration
- Default user: "LeVraiBaptiste" <jane@example.com>
- Work user: "Jane Doe" <jane@work.example.com>
- Directory-based configuration handled via .envrc files

## Environment
- Default shell: Fish with custom aliases and plugins
- System packages managed via environment.systemPackages
- Home configuration managed with home-manager