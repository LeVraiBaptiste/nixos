{ pkgs, lib, ... }:
let
  myScript = builtins.readFile ../../scripts/folderSelect.sh;
in
{
  home-manager.users.bat = { pkgs, ... }: {
    programs.bash.enable = true;
    home.stateVersion = "24.11";

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.kitty = {
      enable = true;
      themeFile = "vague";
      settings = lib.mkDefault {
        update_check_interval = 0;
      };
    };

    # Git credentials per directory
    home.file = {
      "Documents/work/.envrc".text = ''
        export GIT_AUTHOR_NAME="Jane Doe"
        export GIT_AUTHOR_EMAIL="jane@work.example.com"
        export GIT_COMMITTER_NAME="Jane Doe"
        export GIT_COMMITTER_EMAIL="jane@work.example.com"
      '';
      "Documents/work/.folderSelect.sh".text = myScript;

      "Documents/self/.envrc".text = ''
        export GIT_AUTHOR_NAME="LeVraiBaptiste"
        export GIT_AUTHOR_EMAIL="jane@example.com"
        export GIT_COMMITTER_NAME="LeVraiBaptiste"
        export GIT_COMMITTER_EMAIL="jane@example.com"
      '';
      "Documents/self/.folderSelect.sh".text = myScript;
    };

    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "LeVraiBaptiste";
          email = "jane@example.com";
        };
      };
      includes = [
        {
          condition = "gitdir:~/Documents/work/";
          contents = {
            user = {
              name = "Jane Doe";
              email = "jane@work.example.com";
            };
          };
        }
        {
          condition = "gitdir:~/Documents/self/";
          contents = {
            user = {
              name = "LeVraiBaptiste";
              email = "jane@example.com";
            };
          };
        }
      ];
    };
  };
}
