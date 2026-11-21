{ pkgs, ... }:
{
  services.blueman.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez;
    settings = {
      General = {
        Experimental = true;
      };
      Input = {
        ClassicBondedOnly = false;
      };
    };
    disabledPlugins = [ "sap" ];
  };
}
