# Docker Compose deployment — single compose project per host
{ config, lib, pkgs, ... }:
{
  options.homelab.compose.directory = lib.mkOption {
    type = lib.types.path;
    description = "Path to the directory containing docker-compose.yml and related config";
  };

  config = {
    environment.etc."docker-compose".source = config.homelab.compose.directory;

    systemd.services.docker-compose = {
      description = "Docker Compose services";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      restartTriggers = [ config.homelab.compose.directory ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/etc/docker-compose";
        ExecStart = "${pkgs.docker}/bin/docker compose up -d --remove-orphans";
        ExecStop = "${pkgs.docker}/bin/docker compose down";
      };
    };
  };
}
