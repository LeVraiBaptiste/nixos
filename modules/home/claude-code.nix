# Claude Code configuration
# NOTE: ~/.claude/settings.json is managed by NixOS as a read-only symlink.
# statusLine points at the claude-foreman binary: it renders the status bar AND
# records per-pane telemetry that the claude-foreman TUI reads to show each
# session's status (busy/idle/waiting). No hooks — see the claude-foreman flake.
{ pkgs, inputs, ... }:
{
  home-manager.users.bat = {
    home.file.".claude/settings.json".force = true;
    home.file.".claude/settings.json".text = builtins.toJSON {
      statusLine = inputs.claude-foreman.lib.statusLine pkgs;
      attribution = {
        commit = "";
        pr = "";
      };
    };
  };
}
