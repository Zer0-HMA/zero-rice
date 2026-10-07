-- ═══════════════ Rice de zr0_humber_ ═══════════════
-- Se carga con require("rice") al final de hyprland.lua,
-- así que lo que pongas aquí le gana a lo de arriba.
-- Si algo truena, Hyprland te lo marca arriba en rojo.

local cyan    = "rgba(22d3eeff)"   -- acento  (paleta.sh cambia estos valores)
local rosa    = "rgba(ec4899ff)"   -- acento2
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts"

--------------------
---- AUTOINICIO ----
--------------------
hl.on("hyprland.start", function()
    hl.exec_cmd(scripts .. "/wall.sh restaurar")   -- fondo de pantalla
    hl.exec_cmd("swaync")                           -- notificaciones
    hl.exec_cmd(scripts .. "/barra.sh")             -- barra con guardián
end)

------------------
---- VENTANAS ----
------------------
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 12,
        border_size = 2,
        col = {
            active_border   = { colors = { cyan, rosa }, angle = 45 },
            inactive_border = "rgba(2a2a3aaa)",
        },
    },

    decoration = {
        rounding         = 12,
        active_opacity   = 1.0,
        inactive_opacity = 0.92,
        blur   = { enabled = true, size = 6, passes = 3, vibrancy = 0.17 },
        shadow = { enabled = true, range = 20, render_power = 3, color = 0xaa000000 },
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

---------------------
---- ANIMACIONES ----
---------------------
hl.curve("zeroSuave",  { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("zeroLineal", { type = "bezier", points = { {0, 0},      {1, 1}      } })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 5,   bezier = "zeroSuave",  style = "popin 80%" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,   bezier = "zeroSuave",  style = "slidefade 20%" })
-- Borde degradado que gira. Si sientes que consume mucho, pon enabled = false
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "zeroLineal", style = "loop" })

--------------------------------------
---- BLUR DETRÁS DE BARRA Y MENÚS ----
--------------------------------------
hl.layer_rule({
    name  = "zero-blur",
    match = { namespace = "^(barra-zero|rofi|swaync-control-center|swaync-notification-window)$" },
    blur         = true,
    ignore_alpha = 0.3,
})

-- Ventana de configuración avanzada de red, flotando
hl.window_rule({
    name  = "red-avanzado-flotante",
    match = { class = "^red-avanzado$" },
    float = true,
})

----------------
---- ATAJOS ----
----------------
for _, k in ipairs({ "SUPER + R", "Print", "SHIFT + Print", "SUPER + Print", "SUPER + SHIFT + Print", "SUPER + SHIFT + S" }) do
    hl.unbind(k)
end

-- Lanzador, barra y menús
hl.bind("SUPER + R",         hl.dsp.exec_cmd(scripts .. "/lanzador.sh"))
hl.bind("SUPER + B",         hl.dsp.exec_cmd(scripts .. "/barra.sh reiniciar"))
hl.bind("SUPER + N",         hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(scripts .. "/red.sh"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd(scripts .. "/paleta.sh menu"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd(scripts .. "/clima.sh ciudad"))

-- Fondos de pantalla
hl.bind("SUPER + W",         hl.dsp.exec_cmd(scripts .. "/wall.sh menu"))
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd(scripts .. "/wall.sh aleatorio"))

-- Capturas de pantalla
hl.bind("Print",                 hl.dsp.exec_cmd(scripts .. "/captura.sh area"))
hl.bind("SUPER + SHIFT + S",     hl.dsp.exec_cmd(scripts .. "/captura.sh area"))
hl.bind("SHIFT + Print",         hl.dsp.exec_cmd(scripts .. "/captura.sh pantalla"))
hl.bind("SUPER + Print",         hl.dsp.exec_cmd(scripts .. "/captura.sh ventana"))
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd(scripts .. "/captura.sh pantalla 5"))

-------------------------------
---- TUS AJUSTES PERSONALES ----
-------------------------------
-- Crea ~/.config/hypr/mio.lua con lo que quieras cambiar (monitores, teclado, más atajos...).
-- Se carga al final, así que le gana a todo lo de arriba, y el instalador nunca lo toca.
do
    local f = io.open(os.getenv("HOME") .. "/.config/hypr/mio.lua", "r")
    if f then
        f:close()
        require("mio")
    end
end
