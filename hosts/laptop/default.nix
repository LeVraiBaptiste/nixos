{
  config,
  pkgs,
  vars,
  ...
}:
{
  networking.hostName = "laptop";

  # Wi-Fi power save holds incoming packets until the next AP beacon (~100 ms jitter on LAN)
  networking.networkmanager.wifi.powersave = false;
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
  ];

  # Wake-on-LAN
  environment.systemPackages = with pkgs; [ wol ];

  # Remote desktop for GPU-accelerated dictation: LAN at home, Nebula elsewhere
  services.dictation-client.remoteHosts = [
    "desktop.local.com"
    vars.nebula.hosts.desktop.ip
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
