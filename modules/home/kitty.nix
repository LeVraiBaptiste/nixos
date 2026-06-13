{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    kitty
  ];

  home-manager.users.bat.xdg.configFile."kitty/kitty.conf".source = ../../config/kitty.conf;
}
