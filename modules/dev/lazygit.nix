{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    lazygit
    delta
  ];

  home-manager.users.bat.xdg.configFile."lazygit/config.yml".source = ../../configs/lazygit.yml;
}
