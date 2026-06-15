{ ... }:
{
  home-manager.users.bat = {
    programs.ssh = {
      enable = true;
      settings = {
        desktop = {
          hostname = "192.168.1.10";
          user = "bat";
        };
        server = {
          hostname = "192.168.1.62";
          user = "bat";
        };
        remote = {
          hostname = "203.0.113.10";
          user = "bat";
        };
      };
    };
  };
}
