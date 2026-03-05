{ config, pkgs, pkgs-unstable, ... }:
{
  # Add git to system packages
  environment.systemPackages = with pkgs; [
    git
    gcc
    vscode
    docker
    nodejs_22

    go


    ffmpeg

    bun
    pnpm
    python3
    mongodb-compass
    gnumake
    pkgs-unstable.claude-code
    kubernetes-helm
  ];
}