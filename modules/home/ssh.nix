{ lib, vars, ... }:
{
  home-manager.users.bat = {
    programs.ssh = {
      enable = true;
      settings = {
        # Over Nebula, at home and away alike: at home the tunnel goes straight over the
        # LAN, so there is no need to switch addresses. If the mesh is down, use the LAN IP.
        desktop = {
          hostname = vars.nebula.hosts.desktop.ip;
          user = "bat";
        };
        server = {
          hostname = vars.nebula.hosts.server.ip;
          user = "bat";
        };
        # remote's SSH is public (over Nebula, it only accepts the server's certificate pull)
        remote = {
          hostname = lib.head (lib.splitString "/" vars.remote.ipv4);
          user = "bat";
        };
      };
    };
  };
}
