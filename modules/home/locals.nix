{ config, lib, pkgs, ... }:
{
    # Set your time zone.
    time.timeZone = "Europe/Paris";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";

    i18n.extraLocaleSettings = {
        LC_ADDRESS = "fr_FR.UTF-8";
        LC_IDENTIFICATION = "fr_FR.UTF-8";
        LC_MEASUREMENT = "fr_FR.UTF-8";
        LC_MONETARY = "fr_FR.UTF-8";
        LC_NAME = "fr_FR.UTF-8";
        LC_NUMERIC = "fr_FR.UTF-8";
        LC_PAPER = "fr_FR.UTF-8";
        LC_TELEPHONE = "fr_FR.UTF-8";
        LC_TIME = "fr_FR.UTF-8";
    };

    # Install spell checking dictionaries for both English and French
    environment.systemPackages = with pkgs; [
        hunspell
        hunspellDicts.en_US
        hunspellDicts.fr-moderne
        
        # For apps using aspell
        aspell
        aspellDicts.en
        aspellDicts.fr
    ];
    
    # Help applications find the dictionaries
    environment.sessionVariables = {
        DICPATH = "${pkgs.hunspellDicts.en_US}/share/hunspell:${pkgs.hunspellDicts.fr-moderne}/share/hunspell";
        HUNSPELL_DICTIONARIES = "${pkgs.hunspellDicts.en_US}/share/hunspell:${pkgs.hunspellDicts.fr-moderne}/share/hunspell";
    };

    # Configure keymap in X11
    services.xserver.xkb = {
        layout = "fr";
        variant = "azerty";
    };

    # Configure console keymap
    console.keyMap = "fr";
}