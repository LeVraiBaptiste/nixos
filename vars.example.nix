{
  domain = "example.com";
  timezone = "Europe/Paris";

  wireguard = {
    remote = "10.0.0.1";
    desktop = "10.0.0.2";
    server = "10.0.0.3";
    remoteEndpoint = "1.2.3.4";
    listenPort = 51820;
    publicKeys = {
      remote = "REDACTED";
      desktop = "REDACTED";
      server = "REDACTED";
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

  secrets.gluetun = {
    vpnServiceProvider = "protonvpn";
    vpnType = "wireguard";
    wireguardPrivateKey = "REDACTED";
    wireguardAddresses = "REDACTED";
    serverCountries = "Switzerland";
  };

  smtp = {
    username = "you@gmail.com";
    sender = "Auth <you@gmail.com>";
  };

  secrets.authelia = {
    jwtSecret = "REDACTED";
    sessionSecret = "REDACTED";
    storageEncryptionKey = "REDACTED";
    smtpPassword = "REDACTED";
  };

  authelia.users.bat = {
    displayname = "Bat";
    passwordHash = "REDACTED";
    email = "bat@example.com";
  };
}
