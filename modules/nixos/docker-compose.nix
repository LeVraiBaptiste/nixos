# Docker Compose deployment — single compose project per host
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.homelab.compose.files = lib.mkOption {
    type = lib.types.attrsOf lib.types.path;
    description = "Files to include in /etc/docker-compose (name → path)";
  };

  config = {
    environment.etc."docker-compose".source = pkgs.linkFarm "compose" (
      lib.mapAttrsToList (name: path: { inherit name path; }) config.homelab.compose.files
    );

    systemd.services.docker-compose = {
      description = "Docker Compose services";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      restartTriggers = lib.attrValues config.homelab.compose.files;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/etc/docker-compose";
        ExecStart = "${pkgs.docker}/bin/docker compose -p homelab up -d --remove-orphans";
        ExecStop = "${pkgs.docker}/bin/docker compose -p homelab down";
      };
    };
  };
}
