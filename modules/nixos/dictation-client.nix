{ config, lib, pkgs, ... }:
let
  cfg = config.services.dictation-client;

  whisperCpu = pkgs.whisper-cpp;

  modelsDir = "/etc/nixos/models";
  stateDir = "/var/lib/whisper-server";
  activeModelLink = "${stateDir}/model.bin";
  defaultModel = "${modelsDir}/ggml-base.bin";

  llmPromptFile = pkgs.writeText "dictation-llm-prompt.txt"
    (builtins.readFile ../../scripts/dictation-llm-prompt.txt);

  dictateScript = pkgs.writeShellScriptBin "dictate" ''
    export WHISPER_REMOTE_HOST="${cfg.remoteHost}"
    ${builtins.readFile ../../scripts/dictate.sh}
  '';
  speechToTextScript = pkgs.writeScriptBin "speech-to-text" ''
    #!${pkgs.python3}/bin/python3
    import os
    os.environ.setdefault("DICTATION_LLM_PROMPT", "${llmPromptFile}")
    os.environ.setdefault("WHISPER_REMOTE_HOST", "${cfg.remoteHost}")
    ${builtins.readFile ../../scripts/speech-to-text.py}
  '';
  setupModelsScript = pkgs.writeShellScriptBin "setup-whisper-models" (builtins.readFile ../../scripts/setup-whisper-models.sh);
  whisperClientScript = pkgs.writeScriptBin "whisper-client" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ../../scripts/whisper-client.py}
  '';
  whisperModelScript = pkgs.writeShellScriptBin "whisper-model" (builtins.readFile ../../scripts/whisper-model.sh);
in
{
  options.services.dictation-client = {
    remoteHost = lib.mkOption {
      type = lib.types.str;
      description = "Hostname or IP of the remote desktop for GPU-accelerated transcription";
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      whisperCpu
      ffmpeg
      wl-clipboard
      libnotify
      pulseaudio
      curl
      dictateScript
      setupModelsScript
      speechToTextScript
      whisperClientScript
      whisperModelScript
    ];

    programs.ydotool.enable = true;

    systemd.services.whisper-server = {
      description = "Whisper speech-to-text server (CPU fallback)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.ffmpeg ];

      serviceConfig = {
        ExecStart = "${whisperCpu}/bin/whisper-server --model ${activeModelLink} --host 127.0.0.1 --port 8080 --convert -l fr --beam-size 5 --best-of 5";
        Restart = "on-failure";
        RestartSec = 5;
        ConditionPathExists = activeModelLink;
      };
    };

    system.activationScripts.whisperModels = {
      text = ''
        mkdir -p ${modelsDir}
        chmod 755 ${modelsDir}
        mkdir -p ${stateDir}
        if [ ! -e ${activeModelLink} ]; then
          ln -sf ${defaultModel} ${activeModelLink}
        fi
      '';
    };
  };
}
