# OVH dedicated server — WireGuard hub, Caddy ingress (internet-facing)
{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/ssh.nix
    ../../modules/nixos/edge.nix
    ../../modules/nixos/nebula.nix
  ];

  # GRUB UEFI boot (OVH firmware doesn't reliably find systemd-boot)
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  # OVH firmware looks for \efi\debian\grubx64.efi — copy GRUB there after each rebuild
  systemd.services.ovh-grub-compat = {
    description = "Copy GRUB to OVH-expected EFI path";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /boot/EFI/debian
      cp /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/debian/grubx64.efi
    '';
  };

  # Serial console for IPMI/SoL
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
  ];

  networking.hostName = "remote";

  # Mesh peer hostnames (Nebula)
  networking.extraHosts = lib.concatStrings (
    lib.mapAttrsToList (name: h: "${h.ip} ${name}\n") (removeAttrs vars.nebula.hosts [ "remote" ])
  );

  # Static networking via systemd-networkd (no NetworkManager on a headless remote)
  networking.networkmanager.enable = false;
  systemd.network.enable = true;
  networking.useNetworkd = true;

  systemd.network.wait-online.enable = false;

  # Workaround: systemd 260+ networkd fails with exit 243/CREDENTIALS on restart
  systemd.services.systemd-networkd.serviceConfig.LoadCredential = lib.mkForce [ ];

  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = vars.remote.mac;
    address = [
      vars.remote.ipv4
      vars.remote.ipv6
    ];
    routes = [
      { Gateway = vars.remote.ipv4Gateway; }
      { Gateway = vars.remote.ipv6Gateway; }
    ];
    dns = [ vars.remote.dns ];
  };

  # IP forwarding — relay traffic between WireGuard peers
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # WireGuard — key readable by systemd-networkd
  systemd.tmpfiles.rules = [
    "z /etc/wireguard/private.key 0640 root systemd-network -"
  ];

  # WireGuard — VPN hub (Desktop + Server + Phone + Laptop connect here)
  systemd.network.netdevs."10-wg0" = {
    netdevConfig = {
      Name = "wg0";
      Kind = "wireguard";
    };
    wireguardConfig = {
      ListenPort = vars.wireguard.listenPort;
      PrivateKeyFile = "/etc/wireguard/private.key";
    };
    wireguardPeers = [
      {
        # Desktop
        PublicKey = vars.wireguard.publicKeys.desktop;
        AllowedIPs = [ "${vars.wireguard.desktop}/32" ];
      }
      {
        # Server
        PublicKey = vars.wireguard.publicKeys.server;
        AllowedIPs = [ "${vars.wireguard.server}/32" ];
      }
      {
        # Phone (Android) — reaches Orca on the desktop
        PublicKey = vars.wireguard.publicKeys.phone;
        AllowedIPs = [ "${vars.wireguard.phone}/32" ];
      }
      {
        # Laptop — roaming, reaches desktop/server from anywhere
        PublicKey = vars.wireguard.publicKeys.laptop;
        AllowedIPs = [ "${vars.wireguard.laptop}/32" ];
      }
    ];
  };

  systemd.network.networks."50-wg0" = {
    matchConfig.Name = "wg0";
    address = [ "${vars.wireguard.remote}/24" ];
  };

  # SSH — key-only auth (internet-facing)
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
    ];
    allowedUDPPorts = [
      vars.wireguard.listenPort
    ];
  };

  # User account
  users.users.bat = {
    isNormalUser = true;
    description = "bat";
    shell = pkgs.bash;
    extraGroups = [ "wheel" ];
  };

  # Passwordless sudo — key-only SSH is the auth boundary
  security.sudo.wheelNeedsPassword = false;

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

    # Networking
    wireguard-tools

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
  ];

  programs.fish.shellAliases = {
    rebuild-remote = "/etc/nixos/scripts/rebuild.sh";
  };

  system.stateVersion = "24.11";
}
