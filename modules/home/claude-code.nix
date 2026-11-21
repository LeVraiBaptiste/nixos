# Claude Code configuration
# ~/.claude/settings.json is a regular, writable file: Orca writes its agent
# hooks there. Nix only owns the keys below, deep-merged into the file at each
# activation (Nix keys win, everything else — Orca's hooks — is kept).
# statusLine points at the claude-foreman binary: it renders the status bar AND
# records per-pane telemetry that the claude-foreman TUI reads to show each
# session's status (busy/idle/waiting). Orca leaves a non-Orca statusLine alone.
{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  managedSettings = pkgs.writeText "claude-settings.json" (
    builtins.toJSON {
      statusLine = inputs.claude-foreman.lib.statusLine pkgs;
      attribution = {
        commit = "";
        pr = "";
      };
    }
  );
in
{
  home-manager.users.bat = { lib, ... }: {
    home.activation.claudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      f="$HOME/.claude/settings.json"
      mkdir -p "$HOME/.claude"
      # Leftover read-only symlink from when home.file managed the whole file
      if [ -L "$f" ]; then
        run cp --remove-destination "$(readlink -f "$f")" "$f"
      fi
      [ -s "$f" ] || echo '{}' > "$f"
      tmp="$(mktemp "$f.XXXXXX")"
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$f" ${managedSettings} > "$tmp" \
        && chmod 644 "$tmp" && run mv "$tmp" "$f" || rm -f "$tmp"
    '';
  };
}
