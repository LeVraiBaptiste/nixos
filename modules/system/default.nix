{ pkgs, ... }:
{
  imports = [
    ./boot.nix
    ./network.nix
    ./bluetooth.nix
    ./gnome-extensions.nix
  ];

  # Audio (PipeWire)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Printing
  services.printing.enable = true;

  # User account
  users.users.bat = {
    isNormalUser = true;
    description = "bat";
    extraGroups = [ "networkmanager" "wheel" "docker" "ydotool" "dialout" ];
  };

  # Allow unfree packages
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  # Run unpatched dynamic binaries on NixOS
  programs.nix-ld.enable = true;

  system.stateVersion = "24.11";
}
