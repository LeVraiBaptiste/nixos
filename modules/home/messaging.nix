{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    discord
    mattermost-desktop
  ];
}
