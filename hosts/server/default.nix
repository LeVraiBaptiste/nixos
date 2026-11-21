# Dell T330 — headless Docker host, managed via SSH
{ config, lib, pkgs, vars, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/network.nix
    ../../modules/nixos/ssh.nix
    ../../modules/nixos/docker.nix
    ../../modules/nixos/docker-compose.nix
  ];

  # Legacy BIOS boot with GRUB (not UEFI)
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  # Kernel tuning — PCIe power saving, disable NMI watchdog
  boot.kernelParams = [ "pcie_aspm.policy=powersave" ];
  boot.kernel.sysctl = {
    "kernel.nmi_watchdog" = 0;
    "vm.dirty_writeback_centisecs" = 1500;
  };

  # CPU governor — bias toward lower frequencies
  powerManagement.cpuFreqGovernor = "powersave";
  powerManagement.powertop.enable = true;

  # IPMI fan control — dynamic speed based on CPU temp
  systemd.services.ipmi-fan-control = {
    description = "Dynamic IPMI fan control for Dell T330";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [ pkgs.ipmitool pkgs.gawk ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash ${../../scripts/ipmi-fan-control.sh}";
      ExecStop = "${pkgs.ipmitool}/bin/ipmitool raw 0x30 0x30 0x01 0x01";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # Home Assistant config backup — auto-commit + push to GitHub daily
  systemd.services.ha-config-backup = {
    description = "Backup Home Assistant config to GitHub";
    path = [ pkgs.git pkgs.openssh ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${../../scripts/ha-config-backup.sh}";
    };
  };

  systemd.timers.ha-config-backup = {
    description = "Daily Home Assistant config backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # WireGuard — VPN client (tunnel to remote hub)
  networking.wireguard.interfaces.wg0 = {
    ips = [ "${vars.wireguard.server}/24" ];
    privateKeyFile = "/etc/wireguard/private.key";
    peers = [{
      publicKey = vars.wireguard.publicKeys.remote;
      endpoint = "${vars.wireguard.remoteEndpoint}:${toString vars.wireguard.listenPort}";
      allowedIPs = [ "10.10.0.0/24" ];
      persistentKeepalive = 25;
    }];
  };

  # Service directories
  systemd.tmpfiles.rules = [
    "d /srv/filebrowser/data 0755 1000 1000 -"
    "d /srv/filebrowser/database 0755 1000 1000 -"
    "d /srv/filebrowser/config 0755 1000 1000 -"
    "d /srv/authelia/data 0755 root root -"
    # Media directories
    "d /srv/media/downloads 0755 1000 1000 -"
    "d /srv/media/tv 0755 1000 1000 -"
    "d /srv/media/movies 0755 1000 1000 -"
    # Arr stack config
    "d /srv/gluetun 0755 1000 1000 -"
    "d /srv/qbittorrent 0755 1000 1000 -"
    "d /srv/prowlarr 0755 1000 1000 -"
    "d /srv/sonarr 0755 1000 1000 -"
    "d /srv/radarr 0755 1000 1000 -"
    "d /srv/shelfarr 0755 1000 1000 -"
    "d /srv/media/ebooks 0755 1000 1000 -"
    "d /srv/audiobookshelf/config 0755 1000 1000 -"
    "d /srv/audiobookshelf/metadata 0755 1000 1000 -"
    "d /srv/media/audiobooks 0755 1000 1000 -"
  ];

  homelab.compose.files = {
    "docker-compose.yml" = pkgs.replaceVars ../../config/server/docker-compose.yml {
      inherit (vars) timezone;
      filebrowser_port = toString vars.services.filebrowser.port;
      # Arr stack
      qbittorrent_port = toString vars.services.qbittorrent.port;
      gluetun_vpn_service_provider = vars.gluetun.vpnServiceProvider;
      gluetun_vpn_type = vars.gluetun.vpnType;
      gluetun_wireguard_addresses = vars.gluetun.wireguardAddresses;
      gluetun_server_countries = vars.gluetun.serverCountries;
      prowlarr_port = toString vars.services.prowlarr.port;
      shelfarr_port = toString vars.services.shelfarr.port;
      audiobookshelf_port = toString vars.services.audiobookshelf.port;
    };
    "Caddyfile" = pkgs.replaceVars ../../config/server/Caddyfile {
      inherit (vars) domain;
      wg_remote = vars.wireguard.remote;
      authelia_port = toString vars.services.authelia.port;
      ha_port = toString vars.services.homeassistant.port;
      jellyfin_port = toString vars.services.jellyfin.port;
      filebrowser_port = toString vars.services.filebrowser.port;
      # Arr stack
      qbittorrent_port = toString vars.services.qbittorrent.port;
      prowlarr_port = toString vars.services.prowlarr.port;
      sonarr_port = toString vars.services.sonarr.port;
      radarr_port = toString vars.services.radarr.port;
      shelfarr_port = toString vars.services.shelfarr.port;
      audiobookshelf_port = toString vars.services.audiobookshelf.port;
    };
    "authelia/configuration.yml" = pkgs.replaceVars ../../config/server/authelia/configuration.yml {
      inherit (vars) domain;
      authelia_port = toString vars.services.authelia.port;
      smtp_username = vars.smtp.username;
      smtp_sender = vars.smtp.sender;
    };
  };

  # Secrets — encrypted in secrets/server.yaml, decrypted with this host's SSH key
  # at activation into /run/secrets (never in the Nix store). Edit with:
  #   sops secrets/server.yaml
  sops = {
    defaultSopsFile = ../../secrets/server.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "authelia/jwt_secret" = { };
      "authelia/session_secret" = { };
      "authelia/storage_encryption_key" = { };
      "authelia/smtp_password" = { };
      "authelia/users/bat/password_hash" = { };
      "gluetun/wireguard_private_key" = { };
    };

    # Rendered files referenced by absolute path from docker-compose.yml
    templates = {
      "authelia.env" = {
        content = ''
          AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET="${config.sops.placeholder."authelia/jwt_secret"}"
          AUTHELIA_SESSION_SECRET="${config.sops.placeholder."authelia/session_secret"}"
          AUTHELIA_STORAGE_ENCRYPTION_KEY="${config.sops.placeholder."authelia/storage_encryption_key"}"
          AUTHELIA_NOTIFIER_SMTP_PASSWORD="${config.sops.placeholder."authelia/smtp_password"}"
        '';
        restartUnits = [ "docker-compose.service" ];
      };
      "gluetun.env" = {
        content = ''
          WIREGUARD_PRIVATE_KEY="${config.sops.placeholder."gluetun/wireguard_private_key"}"
        '';
        restartUnits = [ "docker-compose.service" ];
      };
      # Generate the password hash with:
      #   docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'YOUR_PASSWORD'
      "authelia-users.yml" = {
        content = ''
          users:
            bat:
              displayname: "${vars.authelia.users.bat.displayname}"
              password: "${config.sops.placeholder."authelia/users/bat/password_hash"}"
              email: ${vars.authelia.users.bat.email}
              groups:
                - admins
        '';
        restartUnits = [ "docker-compose.service" ];
      };
    };
  };

  networking.hostName = "server";

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
    ];
    trustedInterfaces = [ "docker0" "br-+" "wg0" ];
  };

  # User account (bash shell required for nixos-rebuild --target-host)
  users.users.bat = {
    isNormalUser = true;
    description = "bat";
    shell = pkgs.bash;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };

  # Fish shell + starship for server
  programs.fish.enable = true;
  programs.starship.enable = true;
  programs.starship.settings = {
    add_newline = false;
    format = "$shell$username$hostname$nix_shell$git_branch$git_commit$git_state$git_status$directory$jobs$cmd_duration$character";
    shell = {
      disabled = false;
      format = "$indicator";
      fish_indicator = "[FISH](bright-blue) ";
      bash_indicator = "[BASH](bright-white) ";
    };
    username = {
      disabled = false;
      style_user = "bright-white bold";
      style_root = "bright-red bold";
    };
    hostname = {
      disabled = false;
      style = "bright-white bold";
    };
  };

  environment.systemPackages = with pkgs; [
    # Fish plugins
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit
    fishPlugins.hydro
    fishPlugins.autopair
    fishPlugins.bass
    fishPlugins.grc
    fishPlugins.z

    # Terminal compatibility
    kitty.terminfo

    # CLI tools
    fzf
    grc
    ripgrep
    bat
    fd
    jq
    git
    htop
    curl
    wget
    tmux
    ipmitool
    docker-compose
    wol
  ];

  programs.fish.shellAliases = {
    rebuild-server = "/etc/nixos/scripts/rebuild.sh";
  };

  system.stateVersion = "24.11";
}
