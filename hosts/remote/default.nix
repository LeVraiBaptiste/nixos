# OVH dedicated server — WireGuard, Caddy, Authelia (internet-facing)
{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/ssh.nix
    ../../modules/nixos/docker.nix
    ../../modules/nixos/docker-compose.nix
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

  # Static networking via systemd-networkd (no NetworkManager on a headless remote)
  networking.networkmanager.enable = false;
  systemd.network.enable = true;
  networking.useNetworkd = true;

  systemd.network.wait-online.enable = false;

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

  # WireGuard — VPN hub (Desktop + Server connect here)
  # TODO: replace public key placeholders after generating keys (see docs/wireguard-setup.md)
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.10.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/private.key";
    peers = [
      {
        # Desktop
        publicKey = "REPLACE_WITH_DESKTOP_PUBLIC_KEY";
        allowedIPs = [ "10.10.0.2/32" ];
      }
      {
        # Server
        publicKey = "REPLACE_WITH_SERVER_PUBLIC_KEY";
        allowedIPs = [ "10.10.0.3/32" ];
      }
    ];
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
      51820
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

  homelab.compose.directory = ../../config/remote;

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
    docker-compose
  ];

  programs.fish.shellAliases = {
    rebuild-remote = "sudo nixos-rebuild switch --flake /etc/nixos#remote";
  };

  system.stateVersion = "24.11";
}
