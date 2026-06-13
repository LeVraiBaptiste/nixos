local o = vim.opt

-- Line numbers
o.number = true
o.relativenumber = true

-- Indentation
o.tabstop = 2
o.shiftwidth = 2
o.softtabstop = 2
o.expandtab = true
o.smartindent = true

-- Search
o.ignorecase = true
o.smartcase = true
o.hlsearch = true
o.incsearch = true

-- UI
o.termguicolors = true
o.signcolumn = "yes"
o.scrolloff = 8
o.sidescrolloff = 8
o.cursorline = true
o.splitbelow = true
o.splitright = true

-- System clipboard
o.clipboard = "unnamedplus"

-- Undo
o.undofile = true

-- Performance
o.updatetime = 250
o.timeoutlen = 400
