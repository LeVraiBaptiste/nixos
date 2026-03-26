{ pkgs, ... }:
{
  imports = [
    ./locals.nix
    ./home.nix
  ];

  # Logitech device manager (battery levels, settings)
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  environment.systemPackages = with pkgs; [
    # Apps
    discord
    gimp
    qbittorrent
    vlc

    # Utilities
    usbimager
  ];
}
