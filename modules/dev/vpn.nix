{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    openvpn
  ];

  services.openvpn.servers = {
    myVPN = {
      config = "config ./openvpn.ovpn";
    };
  };
}
