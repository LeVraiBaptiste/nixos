
{ config, pkgs, environment, ... }:
{
    imports = [
        ./dev.nix
        ./mattermost.nix
        ./terminal.nix
    ];

    environment.systemPackages = with pkgs; [
        qbittorrent
        vlc
        jq
    ];
}