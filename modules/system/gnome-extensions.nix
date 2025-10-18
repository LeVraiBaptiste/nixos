{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnomeExtensions.gtile
    dconf
  ];

  # Enable dconf for GNOME configuration
  programs.dconf.enable = true;
  
}