# Orca IDE (stablyai/orca) — not in nixpkgs, packaged from the upstream AppImage
# Named orca-ide to avoid clashing with the orca screen reader
final: prev: {
  orca-ide =
    let
      pname = "orca-ide";
      version = "1.4.272";

      src = final.fetchurl {
        url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
        hash = "sha256-OfiJ29GxEYKRcsaWN0cqRiQeRZEGRxmjDHmwE4tbHWo=";
      };

      appimageContents = final.appimageTools.extract { inherit pname version src; };
    in
    final.appimageTools.wrapType2 {
      inherit pname version src;

      # The FHS sandbox replaces /etc with a whitelist that omits /etc/fish, so fish
      # in Orca terminals ran without the NixOS config (aliases, interactiveShellInit, starship)
      extraBwrapArgs = [ "--symlink /.host-etc/fish /etc/fish" ];

      extraInstallCommands = ''
        # Install the bundled .desktop entry and icon, pointing Exec at our wrapper
        desktop=$(find ${appimageContents} -maxdepth 1 -name '*.desktop' | head -n1)
        install -Dm444 "$desktop" $out/share/applications/orca-ide.desktop
        sed -i 's|^Exec=[^ ]*|Exec=orca-ide|' $out/share/applications/orca-ide.desktop

        if [ -d ${appimageContents}/usr/share/icons ]; then
          cp -r ${appimageContents}/usr/share/icons $out/share/
        fi
      '';

      meta = {
        description = "IDE for orchestrating AI coding agents across worktrees";
        homepage = "https://github.com/stablyai/orca";
        mainProgram = "orca-ide";
        platforms = [ "x86_64-linux" ];
      };
    };
}
