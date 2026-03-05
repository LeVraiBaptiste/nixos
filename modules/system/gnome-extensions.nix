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

  # GNOME desktop settings
  programs.dconf.profiles.user.databases = [{
    settings = {
      "org/gnome/desktop/interface" = {
        enable-hot-corners = false;
      };
      "org/gnome/mutter" = {
        dynamic-workspaces = false;
      };
    };
  }];
}