# Public ingress — native Caddy owns 80/443 on remote.
# Base config: relay *.<domain> to the server's Caddy over WireGuard.
# Apps hosted on remote add their own services.caddy.virtualHosts.
{ lib, vars, ... }:
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
    "shelfarr"
    "audiobooks"
  ];

  # The server's Caddy uses `tls internal`: skip verification, but keep SNI = requested host
  relayToServer = ''
    reverse_proxy https://${vars.wireguard.server} {
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
      lib.genAttrs (map (sub: "${sub}.${vars.domain}") serverSubdomains) (_: {
        extraConfig = relayToServer;
      })
      // {
        # Catch-all: drop plain-HTTP requests for hosts nobody declared.
        # Declared hosts keep their automatic HTTP→HTTPS redirect (more specific match).
        # Unknown hosts on 443 fail the TLS handshake (no certificate).
        ":80".extraConfig = "abort";
      };
  };
}
