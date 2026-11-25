# Public ingress — native Caddy owns 80/443 on remote.
# Base config: relay *.<domain> to the server's Caddy over Nebula.
# Apps hosted on remote add their own services.caddy.virtualHosts.
# The certificates of the server's subdomains are also exported to the server
# (pulled by modules/nixos/edge-certs.nix), so LAN clients can reach it directly.
{
  lib,
  pkgs,
  vars,
  ...
}:
let

  # Subdomains served by the home server (routed there by its own Caddy)
  serverSubdomains = [
    "assistant"
    "medias"
    "files"
    "auth"
    "torrents"
    "prowlarr"
    "sonarr"
    "radarr"
    "bazarr"
    "shelfarr"
    "audiobooks"
  ];

  serverHosts = map (sub: "${sub}.${vars.domain}") serverSubdomains;

  # tar of the server's certificates and keys on stdout, run as caddy
  exportCerts = pkgs.writeShellScript "export-edge-certs" ''
    cd /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory
    exec ${pkgs.gnutar}/bin/tar -cf - ${
      lib.concatMapStringsSep " " (h: "${h}/${h}.crt ${h}/${h}.key") serverHosts
    }
  '';

  # Verification stays off: if the server's copy ever expires, the public path keeps
  # working. The hop is inside Nebula, already authenticated by certificate.
  relayToServer = ''
    reverse_proxy https://${vars.nebula.hosts.server.ip} {
      header_up Host {host}
      header_up X-Forwarded-Proto {scheme}
      transport http {
        tls_insecure_skip_verify
        tls_server_name {host}
      }
    }
  '';
in
{
  services.caddy = {
    enable = true;

    virtualHosts =
      lib.genAttrs serverHosts (_: {
        extraConfig = relayToServer;
      })
      // {
        # Catch-all: drop plain-HTTP requests for hosts nobody declared.
        # Declared hosts keep their automatic HTTP→HTTPS redirect (more specific match).
        # Unknown hosts on 443 fail the TLS handshake (no certificate).
        ":80".extraConfig = "abort";
      };
  };

  # The server pulls the certificates over SSH: this user can only run the export,
  # only from the server's Nebula IP (bound to its certificate)
  users.users.edge-certs = {
    isSystemUser = true;
    group = "edge-certs";
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      ''restrict,from="${vars.nebula.hosts.server.ip}",command="/run/wrappers/bin/sudo -n -u caddy ${exportCerts}" ${vars.edgeCerts.clientKey}''
    ];
  };
  users.groups.edge-certs = { };

  security.sudo.extraRules = [
    {
      users = [ "edge-certs" ];
      runAs = "caddy";
      commands = [
        {
          command = "${exportCerts}";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
