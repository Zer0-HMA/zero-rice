-- zero — los colores de Neovim salen de la paleta del rice
--
-- paleta.sh escribe ~/.config/rice-nvim/paleta.lua (plantilla nvim-colores.lua.tpl).
-- Aquí se convierte en un esquema base16 (mini.base16) y se vigila el archivo:
-- cuando cambias de paleta, todos los Neovim abiertos se repintan solos.
local M = {}

local cfg = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
M.dir = cfg .. "/rice-nvim"
M.ruta = M.dir .. "/paleta.lua"

-- ── utilidades de color ──
local function valido(c)
  return type(c) == "string" and c:match("^#%x%x%x%x%x%x$") ~= nil
end

local function rgb(h)
  h = h:gsub("#", "")
  return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
end

-- mezcla(a, b, p) → color que es p % de b y el resto de a (igual que lib/color.sh)
local function mezcla(a, b, p)
  local r1, g1, b1 = rgb(a)
  local r2, g2, b2 = rgb(b)
  local function f(x, y)
    return math.floor((x * (100 - p) + y * p) / 100 + 0.5)
  end
  return string.format("#%02x%02x%02x", f(r1, r2), f(g1, g2), f(b1, b2))
end
M.mezcla = mezcla

-- ── leer la paleta ──
function M.paleta()
  local ok, p = pcall(dofile, M.ruta)
  if not ok or type(p) ~= "table" then return nil end
  for _, k in ipairs({ "fondo", "texto", "tenue", "acento", "acento2" }) do
    if not valido(p[k]) then return nil end
  end
  if type(p.ansi) ~= "table" then return nil end
  for i = 1, 16 do
    if not valido(p.ansi[i]) then return nil end
  end
  return p
end

-- paleta del rice → 16 colores base16
-- (los fondos intermedios se calculan aquí para que siempre contrasten con el fondo)
function M.base16(p)
  local a = p.ansi -- a[1] = color0 … a[16] = color15
  return {
    base00 = p.fondo,                      -- fondo
    base01 = mezcla(p.fondo, p.texto, 7),  -- barras, flotantes
    base02 = mezcla(p.fondo, p.texto, 15), -- selección
    base03 = mezcla(p.fondo, p.texto, 42), -- comentarios
    base04 = p.tenue,                      -- texto secundario
    base05 = p.texto,                      -- texto
    base06 = mezcla(p.texto, "#ffffff", 10),
    base07 = a[16],
    base08 = a[2],      -- rojo: variables, errores
    base09 = p.acento2, -- números, constantes
    base0A = a[4],      -- amarillo: tipos
    base0B = a[3],      -- verde: cadenas
    base0C = a[7],      -- cyan: escapes, regex
    base0D = p.acento,  -- funciones
    base0E = a[6],      -- magenta: palabras clave
    base0F = a[10],
  }
end

local function hl(grupo, opts)
  vim.api.nvim_set_hl(0, grupo, opts)
end

local function sin_fondo(grupo)
  local actual = vim.api.nvim_get_hl(0, { name = grupo, link = false })
  actual.bg = nil
  actual.ctermbg = nil
  hl(grupo, actual)
end

-- detalles que base16 no cubre: acentos, bordes, transparencia
local function retoques(p, b)
  local seleccion = mezcla(p.fondo, p.acento, 25)
  local borde = mezcla(p.fondo, p.acento, 55)

  hl("CursorLineNr", { fg = p.acento, bold = true })
  hl("Visual", { bg = seleccion })
  hl("Search", { fg = p.fondo, bg = p.acento })
  hl("IncSearch", { fg = p.fondo, bg = p.acento2 })
  hl("CurSearch", { fg = p.fondo, bg = p.acento2 })
  hl("MatchParen", { fg = p.acento2, bold = true, underline = true })
  hl("WinSeparator", { fg = borde })
  hl("NormalFloat", { fg = b.base05, bg = b.base01 })
  hl("FloatBorder", { fg = p.acento, bg = b.base01 })
  hl("FloatTitle", { fg = p.fondo, bg = p.acento, bold = true })
  hl("Pmenu", { fg = b.base05, bg = b.base01 })
  hl("PmenuSel", { bg = seleccion, bold = true })

  -- completado (blink.cmp) y buscador (snacks picker) de LazyVim
  hl("BlinkCmpMenu", { link = "Pmenu" })
  hl("BlinkCmpMenuBorder", { link = "FloatBorder" })
  hl("BlinkCmpMenuSelection", { link = "PmenuSel" })
  hl("BlinkCmpDocBorder", { link = "FloatBorder" })
  hl("SnacksPickerBorder", { link = "FloatBorder" })
  hl("SnacksPickerTitle", { link = "FloatTitle" })
  hl("SnacksPickerMatch", { fg = p.acento, bold = true })

  -- pantalla de inicio con el logo de ZERO en tus colores
  hl("SnacksDashboardHeader", { fg = p.acento })
  hl("SnacksDashboardIcon", { fg = p.acento2 })
  hl("SnacksDashboardKey", { fg = p.acento2, bold = true })
  hl("SnacksDashboardDesc", { fg = b.base05 })
  hl("SnacksDashboardFooter", { fg = b.base04, italic = true })

  if vim.g.zero_transparente ~= false then
    for _, g in ipairs({ "Normal", "NormalNC", "SignColumn", "EndOfBuffer", "LineNr", "FoldColumn", "CursorLineNr" }) do
      sin_fondo(g)
    end
  end
end

-- ── aplicar ──
function M.aplicar()
  local p = M.paleta()
  if not p then
    -- todavía no hay paleta (o Neovim se abrió fuera del rice): un tema decente de respaldo
    if not pcall(vim.cmd.colorscheme, "tokyonight") then pcall(vim.cmd.colorscheme, "habamax") end
    return
  end
  local ok, base16 = pcall(require, "mini.base16")
  if not ok then
    vim.notify("Falta mini.base16 (corre :Lazy sync)", vim.log.levels.WARN, { title = "ZERO" })
    return
  end
  local b = M.base16(p)
  vim.o.background = "dark" -- la terminal del rice siempre es oscura, aun con paletas claras
  base16.setup({ palette = b, use_cterm = true })
  retoques(p, b)
  vim.g.colors_name = "zero"
  M.actual = p.nombre
  -- lualine, bufferline y compañía se repintan con este evento
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "zero", modeline = false })
end

-- ── vigilar la paleta ──
-- paleta.sh escribe un temporal y lo mueve: se vigila la carpeta y se espera a que termine.
local vigilante, espera
function M.vigilar()
  if vigilante then return end
  local uv = vim.uv or vim.loop
  vim.fn.mkdir(M.dir, "p")
  vigilante = uv.new_fs_event()
  if not vigilante then return end
  espera = uv.new_timer()
  vigilante:start(M.dir, {}, function(err, archivo)
    if err or (archivo and archivo ~= "paleta.lua") then return end
    espera:stop()
    espera:start(200, 0, vim.schedule_wrap(function()
      M.aplicar()
    end))
  end)
end

-- para recargar a mano desde fuera:  nvim --server <socket> --remote-expr 'v:lua.ZeroRecargar()'
function _G.ZeroRecargar()
  vim.schedule(M.aplicar)
  return 0
end

vim.api.nvim_create_user_command("ZeroColores", function() M.aplicar() end, { desc = "Recargar los colores del rice" })

return M
