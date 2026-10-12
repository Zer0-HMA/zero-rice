-- Atajos propios: <leader>z… controla el rice sin salir de Neovim
local map = vim.keymap.set
local scripts = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")) .. "/hypr/scripts"

local function rice(...)
  local cmd = { ... }
  cmd[1] = scripts .. "/" .. cmd[1]
  if vim.fn.executable(cmd[1]) == 0 then
    vim.notify("No encontré " .. cmd[1], vim.log.levels.WARN, { title = "ZERO" })
    return
  end
  vim.fn.jobstart(cmd, { detach = true })
end

map("n", "<leader>zp", function() rice("paleta.sh", "menu") end, { desc = "Elegir paleta" })
map("n", "<leader>zn", function() rice("paleta.sh", "siguiente") end, { desc = "Siguiente paleta" })
map("n", "<leader>za", function() rice("paleta.sh", "aleatoria") end, { desc = "Paleta aleatoria" })
map("n", "<leader>zb", function() rice("barra-estilo.sh", "menu") end, { desc = "Estilo de la barra" })
map("n", "<leader>zr", function() require("zero").aplicar() end, { desc = "Recargar colores" })
