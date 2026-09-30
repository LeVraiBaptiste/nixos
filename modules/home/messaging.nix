{ lib, pkgs, ... }:
let
  # mattermost-desktop 6.3.0 bundles the koffi native module without an rpath,
  # so Electron's dlopen fails on libstdc++.so.6 and the app dies at startup.
  # Wrap the launcher with libstdc++ on LD_LIBRARY_PATH, and rewrite the
  # .desktop entry, which hardcodes the unwrapped store path.
  mattermost-desktop = pkgs.symlinkJoin {
    name = "mattermost-desktop-${pkgs.mattermost-desktop.version}";
    paths = [ pkgs.mattermost-desktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm $out/bin/mattermost-desktop
      makeWrapper ${lib.getExe pkgs.mattermost-desktop} $out/bin/mattermost-desktop \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}

      rm $out/share/applications/Mattermost.desktop
      substitute ${pkgs.mattermost-desktop}/share/applications/Mattermost.desktop \
        $out/share/applications/Mattermost.desktop \
        --replace-fail ${pkgs.mattermost-desktop}/bin $out/bin
    '';
    inherit (pkgs.mattermost-desktop) meta;
  };
in
{
  environment.systemPackages = [
    pkgs.discord
    mattermost-desktop
  ];
}
