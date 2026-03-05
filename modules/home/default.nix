{ pkgs, ... }:
{
  imports = [
    ./locals.nix
    ./home.nix
  ];

  environment.systemPackages = with pkgs; [
    # Apps
    discord
    qbittorrent
    vlc

    # Utilities
    usbimager
  ];
}
