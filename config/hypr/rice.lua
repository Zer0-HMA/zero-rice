-- ═══════════════ Rice de zr0_humber_ ═══════════════
-- Se carga con require("rice") al final de hyprland.lua,
-- así que lo que pongas aquí le gana a lo de arriba.
-- Si algo truena, Hyprland te lo marca arriba en rojo.

local cfg     = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local scripts = cfg .. "/hypr/scripts"

-- Colores de la paleta: paleta.sh los escribe en ~/.config/hypr/colores.lua.
-- Se lee el archivo directo (no con require) para que siempre agarre los más recientes.
local col = {
    acento   = "rgba(22d3eeff)",   -- por si colores.lua todavía no existe
    acento2  = "rgba(ec4899ff)",
    inactivo = "rgba(2a2a3aaa)",
}
do
    local f = io.open(cfg .. "/hypr/colores.lua", "r")
    if f then
        local src = f:read("*a")
        f:close()
        local fn = load(src)
        if fn then
            local ok, t = pcall(fn)
            if ok and type(t) == "table" then
                for k, v in pairs(t) do col[k] = v end
            end
        end
    end
end

--------------------
---- AUTOINICIO ----
--------------------
hl.on("hyprland.start", function()
    hl.exec_cmd(scripts .. "/wall.sh restaurar")                  -- fondo de pantalla
    hl.exec_cmd("swaync")                                          -- notificaciones
    hl.exec_cmd(scripts .. "/barra.sh")                            -- barra con guardián
    hl.exec_cmd("systemctl --user start hyprpolkitagent")          -- ventanas de contraseña (polkit)
    hl.exec_cmd("pgrep -x hypridle >/dev/null || hypridle")        -- bloqueo automático (usa zero-lock)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")     -- historial del portapapeles
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
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
            active_border   = { colors = { col.acento, col.acento2 }, angle = 45 },
            inactive_border = col.inactivo,
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
-- Las elige el menú de animaciones (Super + Shift + A) y las escribe en animaciones.lua.
-- Si ese archivo no existe o trae un error, se usan estas de respaldo.
do
    local marca = cfg .. "/rice-animaciones/error"
    local ok, err = pcall(dofile, cfg .. "/hypr/animaciones.lua")
    if ok then
        os.remove(marca)
    else
        local f = io.open(marca, "w")
        if f then f:write(tostring(err)) f:close() end
        hl.curve("zeroSuave",  { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
        hl.curve("zeroLineal", { type = "bezier", points = { {0, 0},      {1, 1}      } })
        hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5,   bezier = "zeroSuave",  style = "popin 80%" })
        hl.animation({ leaf = "workspaces",    enabled = true, speed = 5,   bezier = "zeroSuave",  style = "slidefade 20%" })
        hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 5,   bezier = "zeroSuave",  style = "slidefade 20%" })
        hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5,   bezier = "zeroSuave",  style = "slidefade 20%" })
        -- Borde degradado que gira. Si sientes que consume mucho, pon enabled = false
        hl.animation({ leaf = "borderangle",   enabled = true, speed = 100, bezier = "zeroLineal", style = "loop" })
    end
end

--------------------------------------
---- BLUR DETRÁS DE BARRA Y MENÚS ----
--------------------------------------
hl.layer_rule({
    name  = "zero-blur",
    match = { namespace = "^(barra-zero|osd-zero|rofi|swaync-control-center|swaync-notification-window)$" },
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
for _, k in ipairs({ "SUPER + R", "SUPER + L", "SUPER + SHIFT + L", "SUPER + SHIFT + V", "SUPER + SHIFT + F",
                     "SUPER + SHIFT + A", "Print", "SHIFT + Print", "SUPER + Print", "SUPER + SHIFT + Print",
                     "SUPER + SHIFT + S" }) do
    hl.unbind(k)
end

-- Lanzador, barra y menús
hl.bind("SUPER + R",         hl.dsp.exec_cmd(scripts .. "/lanzador.sh"))
hl.bind("SUPER + B",         hl.dsp.exec_cmd(scripts .. "/barra.sh reiniciar"))
hl.bind("SUPER + N",         hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(scripts .. "/red.sh"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd(scripts .. "/paleta.sh menu"))
hl.bind("SUPER + CTRL + P",  hl.dsp.exec_cmd(scripts .. "/paleta.sh siguiente"))
hl.bind("SUPER + ALT + P",   hl.dsp.exec_cmd(scripts .. "/paleta.sh aleatoria"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd(scripts .. "/clima.sh ciudad"))
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd(scripts .. "/portapapeles.sh"))
hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd(scripts .. "/perfil.sh menu"))        -- foto de perfil y nombre
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd(scripts .. "/animaciones.sh menu"))   -- menú de animaciones

-- Pantalla de bloqueo (zero-lock)
hl.bind("SUPER + L",         hl.dsp.exec_cmd(scripts .. "/zero-lock.sh lock"))     -- bloquear pantalla
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd(scripts .. "/zero-lock.sh"))          -- personalizar el bloqueo (estilo, fondo, colores)

-- Fondos de pantalla
hl.bind("SUPER + W",         hl.dsp.exec_cmd(scripts .. "/wall.sh menu"))
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd(scripts .. "/wall.sh aleatorio"))
hl.bind("SUPER + SHIFT + I", hl.dsp.exec_cmd(scripts .. "/elegir-fondo.sh"))           -- elegir una imagen tuya de cualquier carpeta
hl.bind("SUPER + ALT + I",   hl.dsp.exec_cmd(scripts .. "/paleta.sh menu imagenes"))   -- paletas de tus imágenes

-- Capturas de pantalla
hl.bind("Print",                 hl.dsp.exec_cmd(scripts .. "/captura.sh area"))
hl.bind("SUPER + SHIFT + S",     hl.dsp.exec_cmd(scripts .. "/captura.sh area"))
hl.bind("SHIFT + Print",         hl.dsp.exec_cmd(scripts .. "/captura.sh pantalla"))
hl.bind("SUPER + Print",         hl.dsp.exec_cmd(scripts .. "/captura.sh ventana"))
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd(scripts .. "/captura.sh pantalla 5"))

--------------------------
---- WORKSPACES EN 3D ----
--------------------------
-- Super + número y Super + rueda pasan por ws3d.sh: si elegiste un efecto 3D (Super + Shift + E)
-- lo dibuja la barra; si no, o si la barra no está corriendo, cambian normal.
do
    local ws3d = scripts .. "/ws3d.sh"
    for i = 1, 10 do
        local tecla = "SUPER + " .. (i % 10)
        hl.unbind(tecla)
        hl.bind(tecla, hl.dsp.exec_cmd(ws3d .. " " .. i))
    end
    hl.unbind("SUPER + mouse_down")
    hl.unbind("SUPER + mouse_up")
    hl.unbind("SUPER + SHIFT + E")
    hl.bind("SUPER + mouse_down", hl.dsp.exec_cmd(ws3d .. " e+1"))
    hl.bind("SUPER + mouse_up",   hl.dsp.exec_cmd(ws3d .. " e-1"))
    hl.bind("SUPER + SHIFT + E",  hl.dsp.exec_cmd(ws3d .. " menu"))
end
-- la capa del efecto aparece y se va de golpe (la animación la hace ella misma)
hl.layer_rule({
    name    = "zero-ws3d",
    match   = { namespace = "^zero-ws3d$" },
    no_anim = true,
})

-------------------------------
---- TUS AJUSTES PERSONALES ----
-------------------------------
-- Crea ~/.config/hypr/mio.lua con lo que quieras cambiar (monitores, teclado, más atajos...).
-- Se carga al final, así que le gana a todo lo de arriba, y el instalador nunca lo toca.
do
    local f = io.open(cfg .. "/hypr/mio.lua", "r")
    if f then
        f:close()
        require("mio")
    end
end
