{
  description = "Slippi Dolphin native build flake for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        dolphin-slippi = pkgs.stdenv.mkDerivation rec {
          pname = "slippi-dolphin";
          version = "3.4.6";

          src = pkgs.fetchFromGitHub {
            owner = "project-slippi";
            repo = "Ishiiruka";
            rev = "v${version}";
            sha256 = "sha256-dxSKvXO+ViXGoEZtPg6KPt4/4U8xcdDGkhwF5m9w2LU=";

          };

  nativeBuildInputs = with pkgs; [
    cmake
    pkg-config
    rustc
    cargo
    gtk3           # GTK3 dev headers
    wxwidgets
             # wxWidgets with GTK3 support
    hidapi         # HIDAPI dev files
    glib           # For glib-config include dir
    freetype       # For font rendering (already found, keep it)
    # libX11         # X11 client library (likely required)
    # libXrandr      # Xrandr extension library (likely required)
    # libGL          # OpenGL
#   wxGTK
  hidapi
  qt5.qtbase
  qt5.wrapQtAppsHook
  ];

          buildInputs = with pkgs; [
            alsa-lib
            pulseaudio
            ffmpeg
            libGL
            xorg.libX11
            xorg.libXrandr
            xorg.libXext
            xorg.libXi
            xorg.libXdmcp
            xorg.libxcb
            SDL2
            zlib
            libevdev
            udev
            bluez
            libusb1
            gtk3
            gsettings-desktop-schemas
            qt5.qtbase
            qt5.qtmultimedia
            qt5.qtsvg
            qt5.qttools
          ];

          cmakeFlags = [
            "-DENABLE_LTO=OFF"
            "-DUSE_SHARED_ENET=ON"
            "-DUSE_DISCORD_PRESENCE=OFF"
            "-DENABLE_ANALYTICS=OFF"
            "-DENABLE_AUTOUPDATE=OFF"
          ];

          installPhase = ''
            mkdir -p $out/bin
            cp Binaries/dolphin-emu $out/bin/dolphin-slippi
          '';
        };
      in {
        packages.default = dolphin-slippi;

        apps.default = flake-utils.lib.mkApp {
          drv = dolphin-slippi;
          exePath = "/bin/dolphin-slippi";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            cmake
            gcc
            pkg-config
            python3
            ffmpeg
            SDL2
            libGL
            xorg.libX11
            xorg.libXrandr
            xorg.libXext
            xorg.libXi
            xorg.libxcb
            zlib
          ];
        };
      });
}
