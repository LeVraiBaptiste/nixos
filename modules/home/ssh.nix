{ vars, ... }:
let
  # "At home" = the server (always on, wired) answers on the LAN. Not the desktop: it may be asleep.
  # Runs via $SHELL (fish), hence bash for /dev/tcp.
  atHome = "timeout 1 bash -c '</dev/tcp/192.168.1.62/22' 2>/dev/null";
in
{
  # Function form: lib.hm (DAG ordering) only exists in home-manager's lib
  home-manager.users.bat = { lib, ... }: {
    programs.ssh = {
      enable = true;
      settings = {
        # Away from home: same aliases, over WireGuard. ssh keeps the first value
        # it sees, so these Match blocks must come before the LAN Host blocks.
        desktop-away = lib.hm.dag.entryBefore [ "desktop" ] {
          header = "Match originalhost desktop !exec \"${atHome}\"";
          hostname = vars.wireguard.desktop;
        };
        server-away = lib.hm.dag.entryBefore [ "server" ] {
          header = "Match originalhost server !exec \"${atHome}\"";
          hostname = vars.wireguard.server;
        };
        desktop = {
          hostname = "192.168.1.10";
          user = "bat";
        };
        server = {
          hostname = "192.168.1.62";
          user = "bat";
        };
        remote = {
          hostname = vars.wireguard.remoteEndpoint;
          user = "bat";
        };
      };
    };
  };
}
