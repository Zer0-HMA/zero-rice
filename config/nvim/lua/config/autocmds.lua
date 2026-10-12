-- Las plantillas del rice (kitty.conf.tpl, ags-colores.css.tpl…) se resaltan como su formato real
vim.filetype.add({
  pattern = {
    [".*%.css%.tpl"] = "css",
    [".*%.lua%.tpl"] = "lua",
    [".*%.rasi%.tpl"] = "rasi",
    [".*%.jsonc%.tpl"] = "jsonc",
    [".*%.zsh%.tpl"] = "zsh",
    [".*%.conf%.tpl"] = "conf",
  },
})
