{ inputs, ... }:

# gamepad-desktop: gamepad as keyboard/mouse with per-app profiles (keyed by wm_class).
# Debug names and focus with `gamepad-desktop --verbose` (stop the user service first).
#
# IMPORTANT: actions are evdev keycodes, i.e. physical QWERTY positions, while the
# layout is AZERTY. So the character "a" is KEY_Q, "w" is KEY_Z, "z" is KEY_W,
# "-" is KEY_6, "_" is KEY_8. Letters t, n, r, c, l, o, x are at the same place.
#
# Layer: LB (BTN_TL) is left unmapped everywhere and used as a modifier,
# "BTN_TL+X" fires when X is pressed while LB is held.
let
  tmuxPrefix = "ctrl+q"; # Ctrl+a on AZERTY
in
{
  imports = [ inputs.gamepad-desktop.nixosModules.default ];

  # uinput + udev access to /dev/uinput and gamepads for the active session
  hardware.gamepad-desktop.enable = true;

  home-manager.users.bat = {
    imports = [ inputs.gamepad-desktop.homeManagerModules.default ];

    services.gamepad-desktop = {
      enable = true;
      settings = {
        settings = {
          sensitivity = 1200;
          scroll_speed = 15;
        };

        default = {
          RSTICK = "cursor";
          LSTICK = "scroll";
          BTN_SOUTH = "BTN_LEFT"; # A
          BTN_EAST = "BTN_RIGHT"; # B
          BTN_THUMBR = "BTN_MIDDLE"; # R3
          BTN_TR = "alt-tab"; # RB: hold, d-pad to pick, release
          BTN_START = "enter";
          BTN_MODE = "super"; # Guide: GNOME overview
          DPAD_UP = "up";
          DPAD_DOWN = "down";
          DPAD_LEFT = "left";
          DPAD_RIGHT = "right";
          # Back then Start: release the gamepad for games (Steam), and back.
          # BTN_SELECT stays unmapped since the first button of a combo still fires.
          "BTN_SELECT+BTN_START" = "pause";
        };

        # tmux in kitty (bindings from config/tmux.conf)
        app.kitty = {
          BTN_EAST = "esc"; # B: cancel / Claude Code interrupt
          BTN_WEST = "ctrl+c"; # X
          BTN_NORTH = "ctrl+n"; # Y: new tmux window
          BTN_THUMBL = "tab"; # L3: completion
          BTN_TL2 = "ctrl+shift+left"; # LT: previous window
          BTN_TR2 = "ctrl+shift+right"; # RT: next window

          # LB layer
          "BTN_TL+DPAD_UP" = "shift+up"; # select pane
          "BTN_TL+DPAD_DOWN" = "shift+down";
          "BTN_TL+DPAD_LEFT" = "shift+left";
          "BTN_TL+DPAD_RIGHT" = "shift+right";
          "BTN_TL+BTN_NORTH" = "${tmuxPrefix}, 6"; # prefix - : split side by side
          "BTN_TL+BTN_WEST" = "${tmuxPrefix}, 8"; # prefix _ : split stacked
          "BTN_TL+BTN_SOUTH" = "${tmuxPrefix}, w"; # prefix z : zoom pane
          "BTN_TL+BTN_EAST" = "ctrl+z"; # Ctrl+w: kill pane
          "BTN_TL+BTN_START" = "${tmuxPrefix}, x"; # copy mode
          "BTN_TL+BTN_TL2" = "ctrl+shift+up"; # previous session
          "BTN_TL+BTN_TR2" = "ctrl+shift+down"; # next session
        };

        # Zen browser
        app.zen = {
          BTN_EAST = "alt+left"; # B: back
          BTN_WEST = "ctrl+z"; # X: Ctrl+w, close tab
          BTN_NORTH = "ctrl+t"; # Y: new tab
          BTN_THUMBL = "esc"; # L3: exit fullscreen, close popups
          BTN_TL2 = "ctrl+pageup"; # LT: previous tab
          BTN_TR2 = "ctrl+pagedown"; # RT: next tab

          # LB layer
          "BTN_TL+BTN_EAST" = "alt+right"; # forward
          "BTN_TL+BTN_WEST" = "ctrl+shift+t"; # reopen closed tab
          "BTN_TL+BTN_NORTH" = "ctrl+l"; # address bar
          "BTN_TL+BTN_SOUTH" = "f5"; # reload
          "BTN_TL+DPAD_UP" = "ctrl+equal"; # zoom in
          "BTN_TL+DPAD_DOWN" = "ctrl+6"; # Ctrl+- : zoom out
          "BTN_TL+DPAD_LEFT" = "home";
          "BTN_TL+DPAD_RIGHT" = "end";
        };
      };
    };
  };
}
