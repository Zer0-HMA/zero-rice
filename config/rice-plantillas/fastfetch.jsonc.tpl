#@ destino: ~/.config/rice-terminal/fastfetch.jsonc
#@ requiere: cmd fastfetch
// Generado por paleta.sh — paleta: {{nombre}}
// (los íconos son escapes \uXXXX de Nerd Font; así no se pierden al copiar el archivo)
{
    "logo": {
        "type": "small",
        "color": { "1": "{{term_acento.ansi}}", "2": "{{term_acento2.ansi}}" },
        "padding": { "top": 1, "left": 1, "right": 3 }
    },
    "display": {
        "separator": "  ",
        "color": {
            "keys": "{{term_acento.ansi}}",
            "title": "{{term_acento2.ansi}}",
            "separator": "{{term_tenue.ansi}}",
            "output": "{{term_texto.ansi}}"
        }
    },
    "modules": [
        "title",
        { "type": "custom", "format": "{#{{term_tenue.ansi}}}──────────────────────────" },
        { "type": "os",       "key": "\uF303 OS",      "keyWidth": 10 },
        { "type": "wm",       "key": "\uF2D0 WM",      "keyWidth": 10 },
        { "type": "shell",    "key": "\uF120 Shell", "keyWidth": 10 },
        { "type": "terminal", "key": "\uDB80\uDD8D Term",   "keyWidth": 10 },
        { "type": "cpu",      "key": "\uF2DB CPU",    "keyWidth": 10, "format": "{name}" },
        { "type": "memory",   "key": "\uDB80\uDF5B RAM",    "keyWidth": 10 },
        { "type": "packages", "key": "\uF1B2 Pkgs",   "keyWidth": 10 },
        { "type": "uptime",   "key": "\uF017 Up",      "keyWidth": 10 },
        { "type": "custom",   "key": "\uDB80\uDFD8 Paleta", "keyWidth": 10, "format": "{{nombre}}" },
        "break",
        { "type": "colors", "symbol": "circle", "paddingLeft": 0 }
    ]
}
