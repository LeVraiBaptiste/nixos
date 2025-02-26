{ config, pkgs, environment, ... }:
{
    programs.fish = {
      enable = true;
      shellAliases = {
        gtnix = "cd /etc/nixos && code .";
        rebuild-desktop = "sudo nixos-rebuild switch -I nixos-config=/etc/nixos/hosts/desktop.nix";
        ll = "ls -la";
        docs= "cd ~/Documents";
        work= "cd ~/Documents/work && . .folderSelect.sh && code .";
        self= "cd ~/Documents/self && . .folderSelect.sh && code .";
        home= "cd ~";
      };
    };

    environment.systemPackages = with pkgs; [
      # terms
      fishPlugins.done
      fishPlugins.fzf-fish
      fishPlugins.forgit
      fishPlugins.hydro
      fishPlugins.autopair
      fishPlugins.bass
      fzf
      fishPlugins.grc
      grc
      fishPlugins.z
      ripgrep
      bat
      fd
    ];

    # Make zsh the default shell for your user
    users.users.bat.shell = pkgs.fish;

    programs.starship.enable = true;
    programs.starship.settings = {
      add_newline = false;
      format = "$shell$username$hostname$nix_shell$git_branch$git_commit$git_state$git_status$directory$jobs$cmd_duration$character";
      shell = {
        disabled = false;
        format = "$indicator";
        fish_indicator = "[FISH](bright-blue) ";
        bash_indicator = "[BASH](bright-white) ";
        zsh_indicator = "[ZSH](bright-white) ";
      };
      username = {
        disabled = false;
        style_user = "bright-white bold";
        style_root = "bright-red bold";
      };
      hostname = {
        disabled = false;
        style = "bright-white bold";
      };
    };

}