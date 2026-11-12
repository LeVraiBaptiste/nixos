# OVH dedicated server — WireGuard hub, Caddy ingress, factory (internet-facing)
{ config, lib, pkgs, ... }:
let
  vars = import ../../vars.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/ssh.nix
    ../../modules/nixos/docker.nix
    ../../modules/nixos/edge.nix
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
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];

  networking.hostName = "remote";

  # WireGuard peer hostnames
  networking.extraHosts = ''
    ${vars.wireguard.desktop} desktop
    ${vars.wireguard.server} server
    ${vars.wireguard.phone} phone
    ${vars.wireguard.laptop} laptop
  '';

  # Static networking via systemd-networkd (no NetworkManager on a headless remote)
  networking.networkmanager.enable = false;
  systemd.network.enable = true;
  networking.useNetworkd = true;

  systemd.network.wait-online.enable = false;

  # Workaround: systemd 260+ networkd fails with exit 243/CREDENTIALS on restart
  systemd.services.systemd-networkd.serviceConfig.LoadCredential = lib.mkForce [];

  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "00:00:00:00:00:00";
    address = [
      "203.0.113.10/24"
      "2001:db8::1/128"
    ];
    routes = [
      { Gateway = "203.0.113.254"; }
      { Gateway = "2001:db8::ff"; }
    ];
    dns = [ "9.9.9.9" ];
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
    extraGroups = [ "wheel" "docker" ];
  };

  # Passwordless sudo — key-only SSH is the auth boundary
  security.sudo.wheelNeedsPassword = false;

  # factory's `kamal` network and SeaweedFS container are Docker objects
  # (the default backend for stateVersion >= 22.05 is podman)
  virtualisation.oci-containers.backend = "docker";

  # factory (github.com/LeVraiBaptiste/factory) — the module comes from the flake input.
  # It owns the Caddy vhosts, Postgres, SeaweedFS and the `deploy` user;
  # Kamal (factory CI over SSH) owns the app containers.
  # Secrets: /var/lib/factory/app.env, written by hand (factory's docs/deploy.md).
  services.factory = {
    enable = true;
    # Public half of the CI key (private half = GitHub secret DEPLOY_SSH_KEY)
    deployKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeP9AuGrk5c1PoYH4dtrgPKgKrTLIw64FJjmAqCYDZY factory-ci-deploy" ];
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
    docker-compose
  ];

  # No local rebuild alias: evaluating needs the private factory repo, which only
  # the desktop can clone. Deploy from the desktop (see CLAUDE.md).

  system.stateVersion = "24.11";
}
