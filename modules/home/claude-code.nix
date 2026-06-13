# Claude Code configuration
# NOTE: ~/.claude/settings.json is managed by NixOS as a read-only symlink.
# To add or change Claude Code settings, edit the JSON below and rebuild.
{ pkgs, ... }:
{
  home-manager.users.bat = {
    home.file.".claude/settings.json".force = true;
    home.file.".claude/settings.json".text = builtins.toJSON {
      statusLine = {
        type = "command";
        command = "~/.claude/statusline.sh";
        padding = 2;
      };
      attribution = {
        commit = "";
        pr = "";
      };
    };

    home.file.".claude/statusline.sh" = {
      source = ../../scripts/claude-statusline.sh;
      executable = true;
    };
  };
}
