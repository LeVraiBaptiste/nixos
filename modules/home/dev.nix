{ pkgs, pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs; [
    # Languages & runtimes
    gcc
    nodejs_24
    python3
    go
    bun
    pnpm

    # Build tools
    gnumake

    # Dev tools
    gh
    jq
    ffmpeg
    kubernetes-helm
    mongodb-compass

    # Editors
    vscode
    micro
    glow
    pkgs-unstable.claude-code
  ];
}
