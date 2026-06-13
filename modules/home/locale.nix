{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    hunspell
    hunspellDicts.en_US
    hunspellDicts.fr-moderne

    aspell
    aspellDicts.en
    aspellDicts.fr
  ];

  environment.sessionVariables = {
    DICPATH = "${pkgs.hunspellDicts.en_US}/share/hunspell:${pkgs.hunspellDicts.fr-moderne}/share/hunspell";
    HUNSPELL_DICTIONARIES = "${pkgs.hunspellDicts.en_US}/share/hunspell:${pkgs.hunspellDicts.fr-moderne}/share/hunspell";
  };

  services.xserver.xkb = {
    layout = "fr";
    variant = "azerty";
  };
}
