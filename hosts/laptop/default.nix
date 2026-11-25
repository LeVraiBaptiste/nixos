{
  config,
  pkgs,
  vars,
  ...
}:
{
  networking.hostName = "laptop";
  imports = [
    ./hardware-configuration.nix

    # System
    ../../modules/nixos/nix.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/network.nix
    ../../modules/nixos/nebula.nix
    ../../modules/nixos/bluetooth.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/intel-graphics.nix
    ../../modules/nixos/docker.nix
    ../../modules/nixos/dictation-client.nix
    ../../modules/nixos/steam.nix
    ../../modules/nixos/brave.nix
    ../../modules/nixos/chromium.nix
    ../../modules/nixos/zen-browser.nix
    ../../modules/nixos/logitech.nix
    ../../modules/nixos/media.nix
    ../../modules/nixos/qbittorrent.nix
    ../../modules/nixos/sshfs.nix

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

  # WireGuard — VPN client (tunnel to remote hub), split tunnel: only 10.10.0.0/24
  networking.wireguard.interfaces.wg0 = {
    ips = [ "${vars.wireguard.laptop}/24" ];
    privateKeyFile = "/etc/wireguard/private.key";
    peers = [
      {
        publicKey = vars.wireguard.publicKeys.remote;
        endpoint = "${vars.wireguard.remoteEndpoint}:${toString vars.wireguard.listenPort}";
        allowedIPs = [ "10.10.0.0/24" ];
        persistentKeepalive = 25;
      }
    ];
  };

  # Wake-on-LAN
  environment.systemPackages = with pkgs; [ wol ];

  # Remote desktop for GPU-accelerated dictation: LAN at home, WireGuard elsewhere
  services.dictation-client.remoteHosts = [
    "desktop.local.com"
    vars.wireguard.desktop
  ];

  # GNOME Desktop Environment
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # User account
  users.users.bat = {
    isNormalUser = true;
    description = "bat";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "ydotool"
      "dialout"
    ];
  };

  # Run unpatched dynamic binaries on NixOS
  programs.nix-ld.enable = true;

  system.stateVersion = "24.11";
}
