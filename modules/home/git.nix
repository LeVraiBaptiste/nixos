{ pkgs, vars, ... }:
let
  inherit (vars.git) personal work;
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

    # Git credentials per directory
    home.file = {
      "Documents/work/.envrc".text = ''
        export GIT_AUTHOR_NAME="${work.name}"
        export GIT_AUTHOR_EMAIL="${work.email}"
        export GIT_COMMITTER_NAME="${work.name}"
        export GIT_COMMITTER_EMAIL="${work.email}"
      '';
      "Documents/work/.folderSelect.sh".text = myScript;

      "Documents/self/.envrc".text = ''
        export GIT_AUTHOR_NAME="${personal.name}"
        export GIT_AUTHOR_EMAIL="${personal.email}"
        export GIT_COMMITTER_NAME="${personal.name}"
        export GIT_COMMITTER_EMAIL="${personal.email}"
      '';
      "Documents/self/.folderSelect.sh".text = myScript;
    };

    programs.git = {
      enable = true;
      settings = {
        user = {
          inherit (personal) name;
          inherit (personal) email;
        };
      };
      includes = [
        {
          condition = "gitdir:~/Documents/work/";
          contents = {
            user = {
              inherit (work) name;
              inherit (work) email;
            };
          };
        }
        {
          condition = "gitdir:~/Documents/self/";
          contents = {
            user = {
              inherit (personal) name;
              inherit (personal) email;
            };
          };
        }
      ];
    };
  };
}
