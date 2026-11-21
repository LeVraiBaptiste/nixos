{ pkgs, ... }:
{
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
