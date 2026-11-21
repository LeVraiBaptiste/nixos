# Shared, non-secret values (committed). Secrets live in secrets/*.yaml (sops).
# Personal values (domain, public IP, identities) are merged on top from private/ (see flake.nix).
{
  timezone = "Europe/Paris";

  wireguard = {
    remote = "10.10.0.1";
    desktop = "10.10.0.2";
    server = "10.10.0.3";
    phone = "10.10.0.4";
    laptop = "10.10.0.5";
    listenPort = 51820;
    publicKeys = {
      remote = "ejj87LpGCf9mrplg7Cg7kiEqRz8Zf55Ub5X2IZh44Aw=";
      desktop = "GXChVAAGz8hbAO4wV7MxjGL73NVnH0lfdIGBJ4tmfV4=";
      server = "EWAOo1afS+rx6V1+Y/Tipv0xwn+X3miPQP6rjrkrC3I=";
      phone = "LyCeczzBiWZ1N4p3xMkAgfnuWPrsgAZjLYRE7wDUTUQ=";
      laptop = "oDk3DX0DqACRVpmhoBCj9zgxpowCgT9Df8i83orExRc=";
    };
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
