# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
  [
    ./laptop-hardware-configuration.nix
    ../modules/system
    ../modules/home
    ../modules/dev
    ../modules/brave.nix
    ../modules/zen-browser.nix
    ../modules/steam.nix
    ../modules/system/virt/docker.nix
    ../modules/dictation-client.nix
    ../modules/paseo.nix
  ];

  # Paseo: client only (connects to desktop daemon)
  paseo.enableDesktop = true;

  # Remote desktop for GPU-accelerated dictation
  services.dictation-client.remoteHost = "desktop.local.com";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

}
