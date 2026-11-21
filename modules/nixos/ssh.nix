{ lib, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Authorized SSH keys — laptop + desktop can access any host with this module
  users.users.bat.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINy7WzmFQYFXV9vQwvawfqudoeSCTgkIcRzbDhUjrb/o"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDC5cRqlfPrf/ddXJ9vklPI2YEF2p3vEtBsHKcnpxAm8kXt5bdN79u2CKLhaewXIdYXmRMdpExiBrshyTOVsECFmqh0jFJP96EZRl8MbfqjUDTMPRqbJnQIMkYlumb2SR+lfwBN8aQ8m0qtxOq2D6/yJiGKIheVHUXAz0hbucI0OogdOTjGwrvXIzrG51ockhksTpk2lz5AX/JngpwqJKNuB3jXIO0xz/dNL+Wgo19lDjD7ZgXQBXXgpy7EkKbaoFYiKRFBEr5HOLFSnjNmpC7+vUlaeVNFCZWZyAeI8MtWsgsDtFti9s2V7/Lc0RHQW84X3cH4AXwWKwkUzPYc8ZA7"
  ];

  networking.firewall.allowedTCPPorts = [ 22 ];
}
