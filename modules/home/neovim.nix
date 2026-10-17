{ pkgs, ... }:
{
  # Upstream pnpmDeps hash for typescript-language-server 6.0.2 is stale (hash mismatch).
  # Remove once nixpkgs fixes it.
  nixpkgs.overlays = [
    (final: prev: {
      typescript-language-server = prev.typescript-language-server.overrideAttrs (old: {
        pnpmDeps = old.pnpmDeps.overrideAttrs {
          outputHash = "sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=";
        };
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    neovim

    # LSP servers
    nil
    typescript-language-server
    pyright
    gopls
    lua-language-server
    vscode-langservers-extracted
    yaml-language-server
    tailwindcss-language-server
    dockerfile-language-server
    bash-language-server

    # Dependencies for Treesitter, Telescope, etc.
    ripgrep
    fd
    tree-sitter
    unzip
    wget
    curl
  ];

  home-manager.users.bat.xdg.configFile."nvim" = {
    source = ../../config/nvim;
    recursive = true;
  };
}
