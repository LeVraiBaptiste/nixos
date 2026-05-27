{ pkgs, ... }:
{
  # Ollama - local LLM server accessible at http://localhost:11434
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    loadModels = [ "gemma4:e4b" ];
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "-1";
    };
  };

  environment.systemPackages = [ pkgs.ollama-cuda ];
}
