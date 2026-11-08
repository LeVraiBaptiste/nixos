{ pkgs, ... }:
{
  programs.fish = {
    enable = true;
    shellInit = ''
      set -gx CLAUDE_CODE_NO_FLICKER 1
    '';
    interactiveShellInit = ''
      # tmux inside Orca: dedicated server (-L orca) with its own resurrect history,
      # one session per Orca worktree. Must start from an Orca terminal so the
      # server inherits Orca's env (agent hooks need ORCA_PANE_KEY).
      function tmux-orca
        if not set -q ORCA_PANE_KEY
          echo "tmux-orca: run this from an Orca terminal" >&2
          return 1
        end
        set -l name (path basename (string replace -r '^.*::' "" -- $ORCA_WORKTREE_ID) | string replace -ra '[.:]' _)
        test -n "$name"; or set name orca
        if not tmux -L orca has-session 2>/dev/null
          tmux -L orca new-session -d -s $name -c $PWD
          tmux -L orca run-shell "bash ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
        end
        tmux -L orca new-session -A -s $name -c $PWD
      end

      # Session picker on terminal open (skip if already in tmux or non-interactive).
      # Skipped in Orca terminals: Orca launches agents in them and fzf would grab the input.
      if status is-interactive; and not set -q TMUX; and test "$TERM_PROGRAM" != Orca
        set choice (printf "tmux\nclaude-foreman\nshell" | fzf --height=5 --layout=reverse --prompt="Session > " --no-info)
        switch "$choice"
          case "tmux"
            if not tmux has-session 2>/dev/null
              tmux new-session -d -s default
              tmux run-shell "bash ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
              exec tmux attach-session -t default
            else
              exec tmux new-session -A -s default
            end
          case "claude-foreman"
            claude-foreman
          case "shell"
            # Continue with normal Fish shell
          case "*"
            # Escape/empty selection: continue with normal shell
        end
      end
    '';
    shellAliases = {
      gtnix = "cd /etc/nixos && . .folderSelect.sh";
      # Bump flake inputs, then custom packages not tracked by flake.lock
      update = "sudo nix flake update --flake /etc/nixos && nix run nixpkgs#nix-update -- --flake --file /etc/nixos orca-ide";
      rebuild = "/etc/nixos/scripts/rebuild.sh";
      rebuild-all = "/etc/nixos/scripts/rebuild-all.sh";
      ll = "ls -la";
      docs = "cd ~/Documents";
      work = "cd ~/Documents/work && . .folderSelect.sh";
      self = "cd ~/Documents/self && . .folderSelect.sh";
      home = "cd ~";
      lg = "lazygit";
      ff = "fd --type f | fzf --preview-window 'right:50%' --preview 'string match -q \"*.md\" {}; and CLICOLOR_FORCE=1 COLORTERM=truecolor glow -s tokyo-night -w 80 {}; or bat --color=always --style=numbers {}' --bind 'ctrl-j:preview-down,ctrl-k:preview-up,ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up,enter:execute[micro {}]'";
      fg = "fzf --ansi --disabled --bind 'start:reload:echo Type to search...' --bind 'change:reload:rg --line-number --color=always -- {q} || true' --delimiter ':' --preview 'bat --color=always --style=numbers --highlight-line {2} {1}' --preview-window '+{2}-5' --bind 'ctrl-j:preview-down,ctrl-k:preview-up,ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up,enter:execute[micro +{2} {1}]'";
      t = "tmux attach || tmux";
      ssh-desktop = "tmux detach-client -E 'ssh bat@desktop.local.com -t tmux new-session -A -s default'";
      wake-desktop = "wol 34:5a:60:19:2a:a7";
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
