-- Opciones propias; LazyVim ya trae casi todo bien: https://lazyvim.org/configuration/general
local opt = vim.opt

opt.relativenumber = true
opt.scrolloff = 6
opt.wrap = false
opt.fillchars = { eob = " " }
opt.pumblend = 0

-- true = el fondo de Neovim es el de kitty (respeta su opacidad y el blur de Hyprland)
vim.g.zero_transparente = true
