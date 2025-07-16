{ config, pkgs,  ... }:
{
  # Add git to system packages
  environment.systemPackages = with pkgs; [
    openvpn
  ];

  services.openvpn.servers = {
    myVPN = {
      config = "config ./openvpn.ovpn";
    };
  };
}