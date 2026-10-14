{ config, pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  services.xserver.videoDrivers = [ "nvidia" "modesetting" ];

  # Do NOT add "nvidia" to boot.initrd.kernelModules: it pulls nvidia.ko (~86 MB)
  # plus GSP firmware (~110 MB) into every initrd (~200 MB each), which fills the
  # 512 MB ESP after two generations. The driver loads fine from the root fs.
  boot.extraModulePackages = [ config.boot.kernelPackages.evdi ];
  boot.kernelParams = [ "loglevel=3" "quiet" "nouveau.modeset=0" "ibt=off" "vt.global_cursor_default=0" ];
  boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];
  boot.kernelPackages = pkgs.linuxPackages;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
