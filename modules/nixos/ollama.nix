{ pkgs, ... }:
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "0.0.0.0";
    loadModels = [ "gemma4:e4b" ];
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "5m";
    };
  };

  networking.firewall.allowedTCPPorts = [ 11434 ];

  environment.systemPackages = [ pkgs.ollama-cuda ];
}
