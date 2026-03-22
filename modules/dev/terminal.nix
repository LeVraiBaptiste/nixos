{ pkgs, ... }:
{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Auto-start tmux on terminal open (skip if already in tmux or non-interactive)
      if status is-interactive; and not set -q TMUX
        # Restore previous sessions if tmux isn't already running
        if not tmux has-session 2>/dev/null
          tmux new-session -d -s default
          tmux run-shell "bash ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
          exec tmux attach-session -t default
        else
          exec tmux new-session -A -s default
        end
      end
    '';
    shellAliases = {
      gtnix = "cd /etc/nixos && code .";
      rebuild-desktop = "sudo nixos-rebuild switch --flake /etc/nixos#desktop";
      rebuild-laptop = "sudo nixos-rebuild switch --flake /etc/nixos#laptop";
      rebuild-server = "sudo nixos-rebuild switch --flake ~/Documents/self/homelab#server --target-host bat@192.168.1.62 --sudo --ask-sudo-password";
      ll = "ls -la";
      docs = "cd ~/Documents";
      work = "cd ~/Documents/work && . .folderSelect.sh";
      self = "cd ~/Documents/self && . .folderSelect.sh";
      home = "cd ~";
      lg = "lazygit";
      ff = "fd --type f | fzf --preview-window 'right:50%' --preview 'string match -q \"*.md\" {}; and CLICOLOR_FORCE=1 COLORTERM=truecolor glow -s tokyo-night -w 80 {}; or bat --color=always --style=numbers {}' --bind 'ctrl-j:preview-down,ctrl-k:preview-up,ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up,enter:execute[micro {}]'";
      fg = "fzf --ansi --disabled --bind 'start:reload:echo Type to search...' --bind 'change:reload:rg --line-number --color=always -- {q} || true' --delimiter ':' --preview 'bat --color=always --style=numbers --highlight-line {2} {1}' --preview-window '+{2}-5' --bind 'ctrl-j:preview-down,ctrl-k:preview-up,ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up,enter:execute[micro +{2} {1}]'";
      t = "tmux attach || tmux";
      ssh-desktop = "ssh bat@desktop.local.com -t tmux new-session -A -s default";
    };
  };

  environment.systemPackages = with pkgs; [
    # Fish plugins
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit
    fishPlugins.hydro
    fishPlugins.autopair
    fishPlugins.bass
    fishPlugins.grc
    fishPlugins.z

    # CLI tools
    fzf
    grc
    ripgrep
    bat
    fd

    # Cloud / DevOps
    doctl
    kubectl
  ];

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
