{ pkgs, pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs; [
    # Languages & runtimes
    gcc
    nodejs_24
    python3
    go
    golangci-lint
    gopls
    delve
    bun
    pnpm

    # Build tools
    gnumake

    # Dev tools
    gh
    jq
    ffmpeg
    kubernetes-helm
    google-cloud-sdk
    mongodb-compass
    openssl
    firebase-tools
    terraform
    sops
    age

    # Editors
    vscode
    pkgs-unstable.orca-ide
    micro
    glow
    pkgs-unstable.claude-code
  ];
}
