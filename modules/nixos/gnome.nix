{ pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    gnomeExtensions.gtile
    gnomeExtensions.draw-on-gnome
    gnomeExtensions.vitals
    dconf
  ];

  # Enable dconf for GNOME configuration
  programs.dconf.enable = true;

  # GNOME desktop settings
  programs.dconf.profiles.user.databases = [
    {
      settings = with lib.gvariant; {
        "org/gnome/desktop/interface" = {
          enable-hot-corners = false;
        };
        "org/gnome/mutter" = {
          dynamic-workspaces = false;
        };
        # Disable default Super+Space (input source switching)
        "org/gnome/desktop/wm/keybindings" = {
          switch-input-source = mkEmptyArray type.string;
          switch-input-source-backward = mkEmptyArray type.string;
        };
        # Logitech keyboards' screenshot key sends Super+Shift+S (the Windows
        # snipping shortcut); bind it to the GNOME screenshot UI alongside Print
        "org/gnome/shell/keybindings" = {
          show-screenshot-ui = [
            "Print"
            "<Super><Shift>s"
          ];
        };
        # Register custom keybindings
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          ];
        };
        # Raw dictation: Super+Space
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>space";
          command = "dictate raw";
          name = "Dictation (raw)";
        };
        # LLM dictation: Super+Shift+Space
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          binding = "<Super><Shift>space";
          command = "dictate llm";
          name = "Dictation (LLM)";
        };
      };
    }
  ];
}
