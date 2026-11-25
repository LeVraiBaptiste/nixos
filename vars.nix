# Shared, non-secret values (committed). Secrets live in secrets/*.yaml (sops).
# Personal values (domain, public IP, identities) are merged on top from private/ (see flake.nix).
{
  timezone = "Europe/Paris";

  # Nebula mesh (modules/nixos/nebula.nix). Groups are baked into each certificate by
  # scripts/nebula-cert.sh: changing them means signing the host again.
  nebula = {
    port = 4242;
    lan = "192.168.1.0/24";
    hosts = {
      remote = {
        ip = "10.20.0.1";
        groups = [ "lighthouse" ];
      };
      desktop = {
        ip = "10.20.0.2";
        groups = [ "workstation" ];
      };
      server = {
        ip = "10.20.0.3";
        groups = [ "server" ];
      };
      phone = {
        ip = "10.20.0.4";
        groups = [ "phone" ];
      };
      laptop = {
        ip = "10.20.0.5";
        groups = [ "workstation" ];
      };
    };
  };

  # Public certificates: remote's Caddy obtains them (Let's Encrypt), the server pulls a
  # copy over Nebula so LAN clients can reach it directly (modules/nixos/edge-certs.nix)
  edgeCerts = {
    # The server's pull key (private part in secrets/server.yaml)
    clientKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEkNjxaFXh5qQ8L5myIWuhSuzxsM6OYi3474GDKxs/x9 edge-certs@server";
    # remote's SSH host key, pinned by the server
    remoteHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPc84sS3+X2y37sWX7zQAJY9q1YJnvR2v0E03DXhkg10";
  };

  services = {
    homeassistant.port = 8123;
    jellyfin.port = 8096;
    filebrowser.port = 8090;
    authelia.port = 9091;
    qbittorrent.port = 8080;
    prowlarr.port = 9696;
    sonarr.port = 8989;
    radarr.port = 7878;
    shelfarr.port = 5056;
    audiobookshelf.port = 13378;
  };

  # ProtonVPN via gluetun (private key lives in secrets/server.yaml)
  gluetun = {
    vpnServiceProvider = "protonvpn";
    vpnType = "wireguard";
    wireguardAddresses = "10.2.0.2/32";
    serverCountries = "Netherlands";
  };

  authelia.users.bat = {
    displayname = "Bat";
  };
}
