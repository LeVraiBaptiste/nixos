{ config, pkgs,  ... }:
{
  # Add git to system packages
  environment.systemPackages = with pkgs; [
    git
    vscode
    docker
    nodejs_22
    go
    python3
    mongodb-compass
    # nodePackages."@anthropic-ai/claude-code"
    gnumake
  ];

  # If you're using home-manager, you can use this configuration instead:
#   programs.git = {
#     enable = true;
#     userName = "LeVraiBaptiste";
#     userEmail = "jane@example.com";
    
#     # extraConfig = {
#     # #   init.defaultBranch = "main";
#     #   pull.rebase = true;
#     # #   # Useful aliases
#     # #   aliases = {
#     # #     st = "status";
#     # #     co = "checkout";
#     # #     br = "branch";
#     # #     ci = "commit";
#     # #     last = "log -1 HEAD";
#     # #   };
#     # };
#   };
}