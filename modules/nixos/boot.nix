_: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5; # ESP is only 512 MB
  boot.loader.efi.canTouchEfiVariables = true;
}
