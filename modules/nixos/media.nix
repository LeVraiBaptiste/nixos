{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vlc
    gimp
    usbimager
  ];
}
