# let slippi = (import (builtins.fetchGit {
#   url = "https://github.com/project-slippi/Ishiiruka";
#   rev = "bc4d3c2415f1f37369bf212532c9d1f9cc7a9c86";
#   ref = "slippi";
# })) { };
# in {
#   environment.systemPackages = [
#     slippi.netplay
#     slippi.playback
#   ];
  
# }

{ config, pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.buildFHSUserEnv {
      name = "slippi-launcher";
      targetPkgs = pkgs: with pkgs; [
        libGL
        mesa
        alsa-lib
        pulseaudio
        glib
        gtk3
        # add more as needed
      ];
      runScript = ''
        ${pkgs.appimage-run}/bin/appimage-run /home/bat/Downloads/Slippi-Launcher.AppImage

        export FUSERMOUNT_PROG="${pkgs.fuse}/bin/fusermount"
        exec ${pkgs.appimage-run}/bin/appimage-run /path/to/Slippi-Launcher.AppImage
      '';
    })
  ];
}