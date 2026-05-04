{ pkgs, inputs, ... }:
{
  environment.systemPackages = [
    pkgs.tmux
    pkgs.wl-clipboard
    inputs.claude-foreman.packages.${pkgs.system}.default
  ];

  home-manager.users.bat = {
    home.file.".tmux.conf".source = ../../configs/tmux.conf;

    # Install TPM (Tmux Plugin Manager)
    home.file.".tmux/plugins/tpm" = {
      source = pkgs.fetchFromGitHub {
        owner = "tmux-plugins";
        repo = "tpm";
        rev = "v3.1.0";
        sha256 = "sha256-CeI9Wq6tHqV68woE11lIY4cLoNY8XWyXyMHTDmFKJKI=";
      };
      recursive = true;
    };
  };
}
