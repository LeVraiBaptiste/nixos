{ config, pkgs, vars, ... }:
{
  networking.hostName = "desktop";

  # Allow access to dev servers from LAN
  networking.firewall.allowedTCPPorts = [ 3000 ];

  # Static IP via NetworkManager
  networking.networkmanager.ensureProfiles.profiles.enp12s0-static = {
    connection = {
      id = "enp12s0-static";
      type = "ethernet";
      interface-name = "enp12s0";
      autoconnect = "true";
    };
    ipv4 = {
      method = "manual";
      addresses = "192.168.1.10/24";
      gateway = "192.168.1.1";
      dns = "1.1.1.1;8.8.8.8";
    };
  };

  # WireGuard — VPN client (tunnel to remote hub)
  networking.wireguard.interfaces.wg0 = {
    ips = [ "${vars.wireguard.desktop}/24" ];
    privateKeyFile = "/etc/wireguard/private.key";
    peers = [{
      publicKey = vars.wireguard.publicKeys.remote;
      endpoint = "${vars.wireguard.remoteEndpoint}:${toString vars.wireguard.listenPort}";
      allowedIPs = [ "10.10.0.0/24" ];
      persistentKeepalive = 25;
    }];
  };

  # Orca mobile companion — direct pairing over WireGuard only, never exposed on LAN/WAN
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 6768 ];

  # Prevent suspend on idle (keeps SSH sessions alive when no local user is logged in)
  services.logind.lidSwitchExternalPower = "ignore";
  services.logind.settings.Login.IdleAction = "ignore";

  # Prevent GDM from suspending when no user is logged in
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Wake-on-LAN support
  networking.interfaces.enp12s0.wakeOnLan.enable = true;
  systemd.services.wol-enable = {
    description = "Enable Wake-on-LAN on enp12s0";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ethtool}/bin/ethtool -s enp12s0 wol g";
      RemainAfterExit = true;
    };
  };
  imports = [
    ./hardware-configuration.nix

    # System
    ../../modules/nixos/nix.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/network.nix
    ../../modules/nixos/bluetooth.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/ssh.nix
    ../../modules/nixos/docker.nix

    # Apps
    ../../modules/nixos/dictation.nix
    ../../modules/nixos/ollama.nix
    ../../modules/nixos/obs.nix
    ../../modules/nixos/steam.nix
    ../../modules/nixos/brave.nix
    ../../modules/nixos/chromium.nix
    ../../modules/nixos/zen-browser.nix
    ../../modules/nixos/davinci-resolve.nix
    ../../modules/nixos/logitech.nix
    ../../modules/nixos/media.nix
    ../../modules/nixos/qbittorrent.nix
    ../../modules/nixos/gamepad-desktop.nix

    # Home
    ../../modules/home/ssh.nix
    ../../modules/home/git.nix
    ../../modules/home/locale.nix
    ../../modules/home/fish.nix
    ../../modules/home/tmux.nix
    ../../modules/home/kitty.nix
    ../../modules/home/ghostty.nix
    ../../modules/home/neovim.nix
    ../../modules/home/lazygit.nix
    ../../modules/home/claude-code.nix
    ../../modules/home/dev.nix
    ../../modules/home/messaging.nix
    # ../../modules/home/vpn.nix  # TODO: not imported in original config
  ];

  # GNOME Desktop Environment
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # User account
  users.users.bat = {
    isNormalUser = true;
    description = "bat";
    extraGroups = [ "networkmanager" "wheel" "docker" "ydotool" "dialout" ];
  };

  # Run unpatched dynamic binaries on NixOS
  programs.nix-ld.enable = true;

  system.stateVersion = "24.11";
}
