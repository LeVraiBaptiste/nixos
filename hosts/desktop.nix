# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, environment, ... }:

{
  imports =
  [
    ./hardware-configuration.nix
    ../modules/system
    ../modules/home
    ../modules/dev
    ../modules/brave.nix
    ../modules/steam.nix
    ../modules/system/virt/docker.nix
  ];

   nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Enable the X11 windowing system.
    services.xserver.enable = true;

    # Enable the GNOME Desktop Environment.
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;



}
