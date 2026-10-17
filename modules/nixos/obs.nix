{ config, pkgs, ... }:
let
  # Build an OBS plugin with warnings no longer treated as errors
  noWerror =
    pkg:
    pkg.overrideAttrs (old: {
      env = (old.env or { }) // {
        NIX_CFLAGS_COMPILE = toString (old.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error";
      };
    });
in
{
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-backgroundremoval
      # obs-composite-blur uses -Werror and fails on -Wdiscarded-qualifiers
      # (strrchr on a const char*) with the newer GCC. Drop -Werror until
      # nixpkgs ships a fix.
      (noWerror obs-composite-blur)
      obs-pipewire-audio-capture
      # obs-shaderfilter uses -Werror and fails on a deprecation warning
      # against OBS 32.2.2 (obs_properties_add_button). Drop -Werror until
      # nixpkgs ships a fix.
      (noWerror obs-shaderfilter)
      wlrobs
    ];
  };

  # Virtual camera output (for piping OBS into Zoom/Discord/etc.)
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';
  security.polkit.enable = true;

  # Webcamoid
  environment.systemPackages = [ pkgs.webcamoid ];
}
