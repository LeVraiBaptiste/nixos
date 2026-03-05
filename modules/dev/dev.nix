{ pkgs, pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs; [
    # Languages & runtimes
    gcc
    nodejs_22
    python3
    go
    bun
    pnpm

    # Build tools
    gnumake

    # Dev tools
    jq
    ffmpeg
    kubernetes-helm
    mongodb-compass

    # Editors
    vscode
    pkgs-unstable.claude-code
  ];
}
