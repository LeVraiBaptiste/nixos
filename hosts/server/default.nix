# Dell T330 — headless Docker host, managed via SSH
{ config, lib, pkgs, ... }:
let
  vars = import ../../vars.nix;
in
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
  ];

  homelab.compose.files = {
    "docker-compose.yml" = pkgs.replaceVars ../../config/server/docker-compose.yml {
      inherit (vars) timezone;
      filebrowser_port = toString vars.services.filebrowser.port;
      authelia_jwt_secret = vars.secrets.authelia.jwtSecret;
      authelia_session_secret = vars.secrets.authelia.sessionSecret;
      authelia_storage_encryption_key = vars.secrets.authelia.storageEncryptionKey;
      authelia_smtp_password = vars.secrets.authelia.smtpPassword;
    };
    "Caddyfile" = pkgs.replaceVars ../../config/server/Caddyfile {
      inherit (vars) domain;
      wg_remote = vars.wireguard.remote;
      authelia_port = toString vars.services.authelia.port;
      ha_port = toString vars.services.homeassistant.port;
      jellyfin_port = toString vars.services.jellyfin.port;
      filebrowser_port = toString vars.services.filebrowser.port;
    };
    "authelia/configuration.yml" = pkgs.replaceVars ../../config/server/authelia/configuration.yml {
      inherit (vars) domain;
      authelia_port = toString vars.services.authelia.port;
      smtp_username = vars.smtp.username;
      smtp_sender = vars.smtp.sender;
    };
    "authelia/users_database.yml" = pkgs.replaceVars ../../config/server/authelia/users_database.yml {
      user_bat_displayname = vars.authelia.users.bat.displayname;
      user_bat_password_hash = vars.authelia.users.bat.passwordHash;
      user_bat_email = vars.authelia.users.bat.email;
    };
  };

  networking.hostName = "server";

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      8123
    ];
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
    rebuild-server = "sudo nixos-rebuild switch --flake /etc/nixos#server";
  };

  system.stateVersion = "24.11";
}
