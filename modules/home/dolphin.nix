
{ config, pkgs, environment, services, ... }:
{
    environment.systemPackages = with pkgs; [
        # dolphin-emu
        appimage-run
        # fuse
        # libopengl0
        slippi-netplay
    ];
    # services.flatpak.enable = true;
}