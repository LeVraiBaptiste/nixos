local lspconfig = require("lspconfig")
local nvlsp = require("nvchad.configs.lspconfig")

local on_attach = nvlsp.on_attach
local on_init = nvlsp.on_init
local capabilities = nvlsp.capabilities

-- Servers with default config
local default_servers = {
  "nil_ls",     -- Nix
  "pyright",    -- Python
  "gopls",      -- Go
  "html",       -- HTML
  "cssls",      -- CSS
  "jsonls",     -- JSON
  "yamlls",     -- YAML
  "dockerls",   -- Dockerfile
  "bashls",     -- Bash
}

for _, server in ipairs(default_servers) do
  lspconfig[server].setup({
    on_attach = on_attach,
    on_init = on_init,
    capabilities = capabilities,
  })
end

-- TypeScript
lspconfig.ts_ls.setup({
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  init_options = {
    preferences = {
      disableSuggestions = false,
    },
  },
})

-- Lua (for Neovim config editing)
lspconfig.lua_ls.setup({
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        library = {
          vim.fn.expand("$VIMRUNTIME/lua"),
          vim.fn.stdpath("data") .. "/lazy/ui/nvchad_types",
          vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy",
        },
        maxPreload = 100000,
        preloadFileSize = 10000,
      },
    },
  },
})

-- Tailwind CSS
lspconfig.tailwindcss.setup({
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  filetypes = {
    "html",
    "css",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
})
