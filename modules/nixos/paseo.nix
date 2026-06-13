# Paseo - AI agent orchestration platform
# Daemon runs on desktop, clients connect from laptop/mobile

{ config, lib, inputs, ... }:

let
  cfg = config.paseo;
in
{
  options.paseo = {
    enableDaemon = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Paseo daemon (server mode)";
    };

    enableDesktop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install the Paseo desktop app";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enableDaemon {
      services.paseo = {
        enable = true;
        openFirewall = true;
        listenAddress = "0.0.0.0";
        relay.enable = false;
      };
    })

    (lib.mkIf cfg.enableDesktop {
      environment.systemPackages = [
        inputs.paseo.packages.x86_64-linux.desktop
      ];
    })
  ];
}
