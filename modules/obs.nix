{ config, pkgs, ... }:
{
  # OBS Studio with background blur/removal plugins
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-backgroundremoval       # neural-net segmentation + blur background
      obs-composite-blur          # finer blur control / background compositing
      obs-pipewire-audio-capture  # PipeWire audio capture
      obs-shaderfilter            # custom GLSL shaders (includes ascii.shader)
      wlrobs                     # Wayland screen capture
    ];
  };

  # Virtual camera output (for piping OBS into Zoom/Discord/etc.)
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';
  security.polkit.enable = true;

  # Webcamoid — camera effects, 3D masks, virtual camera output
  environment.systemPackages = [ pkgs.webcamoid ];
}
