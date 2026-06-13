{ config, pkgs, ... }:
{
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-backgroundremoval
      obs-composite-blur
      obs-pipewire-audio-capture
      obs-shaderfilter
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
