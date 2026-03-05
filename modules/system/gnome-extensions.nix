{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnomeExtensions.gtile
    gnomeExtensions.draw-on-gnome
    gnomeExtensions.vitals
    dconf
  ];

  # Enable dconf for GNOME configuration
  programs.dconf.enable = true;
  
}