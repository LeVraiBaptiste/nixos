{ lib, pkgs, ... }:
{
  networking.hostName = lib.mkDefault "nixos";
  networking.networkmanager.enable = true;
  # OpenVPN support: import .ovpn files via `nmcli connection import type openvpn file <file>`
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  environment.systemPackages = with pkgs; [
    dnsutils # dig, nslookup
    openvpn # raw openvpn CLI
  ];
}
