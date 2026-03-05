{ pkgs, ... }:
let
  # Whisper with NVIDIA CUDA acceleration
  whisperCuda = pkgs.whisper-cpp.override { cudaSupport = true; };

  # Create scripts with proper permissions
  dictateScript = pkgs.writeShellScriptBin "dictate" (builtins.readFile ../scripts/dictate.sh);
  setupModelsScript = pkgs.writeShellScriptBin "setup-whisper-models" (builtins.readFile ../scripts/setup-whisper-models.sh);
  speechToTextScript = pkgs.writeScriptBin "speech-to-text" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ../scripts/speech-to-text.py}
  '';
in
{
  environment.systemPackages = with pkgs; [
    whisperCuda
    xdotool
    xclip
    libnotify
    python3
    pulseaudio
    curl
    dictateScript
    setupModelsScript
    speechToTextScript
  ];

  # Create models directory
  system.activationScripts.whisperModels = {
    text = ''
      mkdir -p /etc/nixos/models
      chmod 755 /etc/nixos/models
    '';
  };
}