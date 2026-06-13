{ config, pkgs, ... }:

{
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
    ../../modules/nixos/zen-browser.nix
    ../../modules/nixos/davinci-resolve.nix
    ../../modules/nixos/logitech.nix
    ../../modules/nixos/media.nix
    ../../modules/nixos/qbittorrent.nix

    # Home
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
