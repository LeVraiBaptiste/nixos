{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ghostty
  ];

  home-manager.users.bat.xdg.configFile."ghostty/config".source = ../../config/ghostty.conf;
}
