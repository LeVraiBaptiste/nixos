---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "catppuccin",
  transparency = true,
}

M.ui = {
  statusline = {
    theme = "vscode_colored",
  },
  tabufline = {
    enabled = true,
  },
}

M.mason = {
  -- Disable Mason since LSPs are managed by Nix
  pkgs = {},
}

return M
