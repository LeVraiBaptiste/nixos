# Orca IDE (stablyai/orca) — not in nixpkgs, packaged from the upstream AppImage
# Named orca-ide to avoid clashing with the orca screen reader
final: prev: {
  orca-ide =
    let
      pname = "orca-ide";
      version = "1.4.253";

      src = final.fetchurl {
        url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
        hash = "sha256-/Om67bYXwD3elBxqRAjVurktF9K+0d70AV3b2Pp079w=";
      };

      appimageContents = final.appimageTools.extract { inherit pname version src; };
    in
    final.appimageTools.wrapType2 {
      inherit pname version src;

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
