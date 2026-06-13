{ lib, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = lib.mkDefault true;
      KbdInteractiveAuthentication = lib.mkDefault true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
