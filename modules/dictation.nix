{ pkgs, ... }:
let
  # Whisper with NVIDIA CUDA acceleration
  whisperCuda = pkgs.whisper-cpp.override { cudaSupport = true; };

  modelsDir = "/etc/nixos/models";
  stateDir = "/var/lib/whisper-server";
  activeModelLink = "${stateDir}/model.bin";
  defaultModel = "${modelsDir}/ggml-large-v3-turbo.bin";

  # LLM prompt file for dictation cleanup
  llmPromptFile = pkgs.writeText "dictation-llm-prompt.txt"
    (builtins.readFile ../scripts/dictation-llm-prompt.txt);

  # Create scripts with proper permissions
  dictateScript = pkgs.writeShellScriptBin "dictate" (builtins.readFile ../scripts/dictate.sh);
  setupModelsScript = pkgs.writeShellScriptBin "setup-whisper-models" (builtins.readFile ../scripts/setup-whisper-models.sh);
  speechToTextScript = pkgs.writeScriptBin "speech-to-text" ''
    #!${pkgs.python3}/bin/python3
    import os
    os.environ.setdefault("DICTATION_LLM_PROMPT", "${llmPromptFile}")
    ${builtins.readFile ../scripts/speech-to-text.py}
  '';
  whisperClientScript = pkgs.writeScriptBin "whisper-client" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ../scripts/whisper-client.py}
  '';
  whisperModelScript = pkgs.writeShellScriptBin "whisper-model" (builtins.readFile ../scripts/whisper-model.sh);
in
{
  environment.systemPackages = with pkgs; [
    whisperCuda
    ffmpeg
    wl-clipboard  # Wayland-native clipboard (wl-copy/wl-paste)
    libnotify
    pulseaudio
    curl
    dictateScript
    setupModelsScript
    speechToTextScript
    whisperClientScript
    whisperModelScript
  ];

  # ydotool for Wayland-native key simulation (replaces xdotool)
  programs.ydotool.enable = true;

  # Persistent whisper-server for fast transcription
  systemd.services.whisper-server = {
    description = "Whisper speech-to-text server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.ffmpeg ];

    serviceConfig = {
      ExecStart = "${whisperCuda}/bin/whisper-server --model ${activeModelLink} --host 127.0.0.1 --port 8080 --convert -l fr --beam-size 5 --best-of 5";
      Restart = "on-failure";
      RestartSec = 5;
      ConditionPathExists = activeModelLink;
      SupplementaryGroups = [ "video" "render" ];
    };
  };

  # Create models directory and default symlink
  system.activationScripts.whisperModels = {
    text = ''
      mkdir -p ${modelsDir}
      chmod 755 ${modelsDir}
      mkdir -p ${stateDir}
      # Create default symlink if none exists
      if [ ! -e ${activeModelLink} ]; then
        ln -sf ${defaultModel} ${activeModelLink}
      fi
    '';
  };
}