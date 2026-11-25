# Public certificates for the server's Caddy, pulled from remote (which obtains them from
# Let's Encrypt, see modules/nixos/edge.nix). With them, a client can skip remote and
# talk to the server directly (LAN DNS override, /etc/hosts) without a certificate error.
#
# The pull runs over Nebula with a dedicated key (secrets/server.yaml) that remote only
# accepts for the export command. Copies land in /srv/caddy/certs/<host>/<host>.{crt,key},
# mounted into the Caddy container; Caddy is reloaded when they change.
{
  config,
  pkgs,
  vars,
  ...
}:
let
  dest = "/srv/caddy/certs";
  remoteIp = vars.nebula.hosts.remote.ip;
  knownHosts = pkgs.writeText "edge-certs-known-hosts" "${remoteIp} ${vars.edgeCerts.remoteHostKey}\n";
in
{
  sops.secrets."edge-certs/ssh_key" = { };

  systemd.tmpfiles.rules = [ "d ${dest} 0700 root root -" ];

  systemd.services.edge-certs-sync = {
    description = "Pull the public TLS certificates from remote";
    after = [
      "network-online.target"
      "nebula@homelab.service"
    ];
    wants = [ "network-online.target" ];
    path = [
      pkgs.openssh
      pkgs.gnutar
      pkgs.rsync
      pkgs.docker
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      ssh -i ${config.sops.secrets."edge-certs/ssh_key".path} \
        -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=20 \
        -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${knownHosts} \
        edge-certs@${remoteIp} > "$tmp/certs.tar"
      mkdir "$tmp/new"
      tar -xf "$tmp/certs.tar" -C "$tmp/new"

      # In place (the directory is bind-mounted), only reload when something changed
      changed=$(rsync -rc --delete --chmod=D700,F600 --out-format=%n "$tmp/new/" ${dest}/)
      if [ -n "$changed" ]; then
        echo "updated: $changed"
        docker exec homelab-caddy-1 caddy reload --config /etc/caddy/Caddyfile --force \
          || echo "caddy not running, it will load the certificates on start"
      fi
    '';
  };

  systemd.timers.edge-certs-sync = {
    description = "Pull the public TLS certificates from remote";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  # Caddy needs the files to start: pull them first (a failure does not block it,
  # the previous copy stays in place)
  systemd.services.docker-compose = {
    wants = [ "edge-certs-sync.service" ];
    after = [ "edge-certs-sync.service" ];
  };
}
